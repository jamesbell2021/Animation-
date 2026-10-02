#include "DTDGameMode.h"
#include "DTDCommander.h"
#include "DTDGameState.h"
#include "DTDObjectiveZone.h"
#include "DTDPlayerController.h"
#include "DTDSharedCamera.h"
#include "DTDSquadComponent.h"
#include "DTDSquadStart.h"
#include "DTDUnit.h"
#include "Algo/Sort.h"
#include "Components/CapsuleComponent.h"
#include "EngineUtils.h"
#include "Kismet/GameplayStatics.h"

#define LOCTEXT_NAMESPACE "DTD"

ADTDGameMode::ADTDGameMode()
{
	PrimaryActorTick.bCanEverTick = true;

	PlayerControllerClass = ADTDPlayerController::StaticClass();
	GameStateClass = ADTDGameState::StaticClass();
	DefaultPawnClass = nullptr;
}

void ADTDGameMode::RestartPlayer(AController* NewPlayer)
{
	// No pawn to spawn. The view target is set in SetUpPlayers.
}

void ADTDGameMode::BeginPlay()
{
	Super::BeginPlay();

	// Player 2 (the first gamepad when "Skip Assigning Gamepad to Player 1" is ticked).
	if (!UGameplayStatics::GetPlayerController(this, 1))
	{
		UGameplayStatics::CreatePlayer(this, 1, true);
	}

	for (TActorIterator<ADTDSharedCamera> It(GetWorld()); It; ++It)
	{
		SharedCamera = *It;
		break;
	}
	if (!SharedCamera)
	{
		SharedCamera = GetWorld()->SpawnActor<ADTDSharedCamera>(FVector(0.f, 0.f, 3000.f), FRotator::ZeroRotator);
	}

	for (TActorIterator<ADTDObjectiveZone> It(GetWorld()); It; ++It)
	{
		Objective = *It;
		break;
	}

	for (TActorIterator<ADTDSquadStart> It(GetWorld()); It; ++It)
	{
		PendingStarts.Add(*It);
		bAnyZuluSquads |= (It->Faction == EDTDFaction::Zulu);
	}
	Algo::Sort(PendingStarts, [](const TObjectPtr<ADTDSquadStart>& A, const TObjectPtr<ADTDSquadStart>& B)
	{
		return A->ArrivalSeconds != B->ArrivalSeconds ? A->ArrivalSeconds < B->ArrivalSeconds : A->SquadIndex < B->SquadIndex;
	});

	if (ADTDGameState* State = GetGameState<ADTDGameState>())
	{
		State->MatchLengthSeconds = MatchLengthSeconds;
		State->TimeRemaining = MatchLengthSeconds;
	}

	SetUpPlayers();
	SpawnArrivals();
}

void ADTDGameMode::SetUpPlayers()
{
	const EDTDFaction Player2Faction = Player1Faction == EDTDFaction::British ? EDTDFaction::Zulu : EDTDFaction::British;

	int32 PlayerIndex = 0;
	for (FConstPlayerControllerIterator It = GetWorld()->GetPlayerControllerIterator(); It; ++It)
	{
		ADTDPlayerController* PC = Cast<ADTDPlayerController>(It->Get());
		if (!PC)
		{
			continue;
		}

		PC->SetFaction(PlayerIndex == 0 ? Player1Faction : Player2Faction);
		if (SharedCamera)
		{
			PC->SetViewTarget(SharedCamera);
		}
		++PlayerIndex;
	}
}

void ADTDGameMode::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	if (bMatchOver)
	{
		return;
	}

	Elapsed += DeltaSeconds;
	if (ADTDGameState* State = GetGameState<ADTDGameState>())
	{
		State->ElapsedSeconds = Elapsed;
		State->TimeRemaining = FMath::Max(0.f, MatchLengthSeconds - Elapsed);
	}

	SpawnArrivals();

	WaveTimer += DeltaSeconds;
	if (WaveTimer >= WaveInterval)
	{
		WaveTimer -= WaveInterval;
		SpawnReserves();
	}

	UpdateCountsAndCheckWin(DeltaSeconds);
}

void ADTDGameMode::SpawnArrivals()
{
	while (PendingStarts.Num() > 0)
	{
		ADTDSquadStart* Start = PendingStarts[0];
		if (IsValid(Start) && Start->ArrivalSeconds > Elapsed)
		{
			break;
		}

		PendingStarts.RemoveAt(0);
		if (IsValid(Start))
		{
			SpawnSquad(Start);
		}
	}
}

ADTDCommander* ADTDGameMode::SpawnSquad(ADTDSquadStart* Start)
{
	TSubclassOf<ADTDCommander> CommanderClass = Start->Faction == EDTDFaction::British ? BritishCommanderClass : ZuluCommanderClass;
	if (!CommanderClass)
	{
		CommanderClass = ADTDCommander::StaticClass();
	}

	// Squad Starts sit on the ground; the commander's capsule centre goes half his height above it.
	const float HalfHeight = CommanderClass->GetDefaultObject<ADTDCommander>()->GetCapsuleComponent()->GetScaledCapsuleHalfHeight();
	const FTransform SpawnTransform(
		FRotator(0.f, Start->GetActorRotation().Yaw, 0.f),
		Start->GetActorLocation() + FVector(0.f, 0.f, HalfHeight + 5.f));

	ADTDCommander* Commander = GetWorld()->SpawnActorDeferred<ADTDCommander>(
		CommanderClass, SpawnTransform, nullptr, nullptr, ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn);
	if (!Commander)
	{
		return nullptr;
	}

	Commander->Faction = Start->Faction;
	Commander->SquadName = Start->SquadName;
	Commander->SquadIndex = Start->SquadIndex;

	UDTDSquadComponent* Squad = Commander->Squad;
	Squad->StartingUnits = Start->StartingUnits;
	Squad->ReserveUnits = Start->ReserveUnits;
	if (Start->UnitClassOverride)
	{
		Squad->UnitClass = Start->UnitClassOverride;
	}
	Squad->SetEntry(SpawnTransform);

	Commander->FinishSpawning(SpawnTransform);
	Squad->SpawnUnits(Squad->StartingUnits, false);

	Commanders.Add(Commander);
	bAnyBritishArrived |= (Commander->Faction == EDTDFaction::British);

	// A player with no squad yet takes this one.
	for (FConstPlayerControllerIterator It = GetWorld()->GetPlayerControllerIterator(); It; ++It)
	{
		ADTDPlayerController* PC = Cast<ADTDPlayerController>(It->Get());
		if (PC && PC->GetFaction() == Commander->Faction && !IsValid(PC->GetCommander()))
		{
			PC->SetCommander(Commander);
		}
	}

	return Commander;
}

void ADTDGameMode::SpawnReserves()
{
	int32 ZuluOnField = CountLiveUnits(EDTDFaction::Zulu);

	for (ADTDCommander* Commander : GetCommanders(EDTDFaction::Zulu))
	{
		UDTDSquadComponent* Squad = Commander->Squad;
		int32 Count = FMath::Min(WaveSize, Squad->ReserveUnits);
		Count = FMath::Min(Count, MaxZuluOnField - ZuluOnField);
		if (Count <= 0)
		{
			continue;
		}

		const int32 Spawned = Squad->SpawnUnits(Count, true);
		// If nothing could spawn (no Unit Class), drop those men rather than keep the match waiting on them.
		Squad->ReserveUnits -= Spawned > 0 ? Spawned : Count;
		ZuluOnField += Spawned;
	}

	for (ADTDCommander* Commander : GetCommanders(EDTDFaction::British))
	{
		UDTDSquadComponent* Squad = Commander->Squad;
		const int32 Count = FMath::Min(WaveSize, Squad->ReserveUnits);
		if (Count > 0)
		{
			const int32 Spawned = Squad->SpawnUnits(Count, true);
			Squad->ReserveUnits -= Spawned > 0 ? Spawned : Count;
		}
	}
}

int32 ADTDGameMode::CountLiveUnits(EDTDFaction Faction) const
{
	int32 Count = 0;
	for (const ADTDCommander* Commander : Commanders)
	{
		if (IsValid(Commander) && Commander->Faction == Faction)
		{
			Count += Commander->Squad->GetUnitCount();
		}
	}
	return Count;
}

void ADTDGameMode::UpdateCountsAndCheckWin(float DeltaSeconds)
{
	const int32 British = CountLiveUnits(EDTDFaction::British);
	const int32 Zulu = CountLiveUnits(EDTDFaction::Zulu);

	int32 ZuluToCome = 0;
	bool bZuluStillToArrive = false;
	for (const ADTDCommander* Commander : Commanders)
	{
		if (IsValid(Commander) && Commander->Faction == EDTDFaction::Zulu)
		{
			ZuluToCome += Commander->Squad->ReserveUnits;
		}
	}
	for (const ADTDSquadStart* Start : PendingStarts)
	{
		if (IsValid(Start) && Start->Faction == EDTDFaction::Zulu)
		{
			ZuluToCome += Start->StartingUnits + Start->ReserveUnits;
			bZuluStillToArrive = true;
		}
	}

	ADTDGameState* State = GetGameState<ADTDGameState>();
	if (State)
	{
		State->BritishStanding = British;
		State->ZuluOnField = Zulu;
		State->ZuluToCome = ZuluToCome;
	}

	// The storehouse: Zulu alone inside fills the bar; anything else drains it.
	if (Objective)
	{
		int32 BritishInside = 0;
		int32 ZuluInside = 0;
		Objective->CountInside(BritishInside, ZuluInside);

		const bool bZuluHold = ZuluInside > 0 && BritishInside == 0;
		const float Step = DeltaSeconds / CaptureSeconds;
		const float Progress = FMath::Clamp((State ? State->CaptureProgress : 0.f) + (bZuluHold ? Step : -Step), 0.f, 1.f);
		if (State)
		{
			State->CaptureProgress = Progress;
		}
		if (Progress >= 1.f)
		{
			EndMatch(EDTDFaction::Zulu, LOCTEXT("ZuluStore", "The Zulu army took the storehouse."));
			return;
		}
	}

	if (bAnyBritishArrived && British == 0)
	{
		EndMatch(EDTDFaction::Zulu, LOCTEXT("ZuluOvercome", "The Zulu army overcame the garrison."));
		return;
	}

	if (Elapsed >= MatchLengthSeconds)
	{
		EndMatch(EDTDFaction::British, LOCTEXT("BritishDawn", "The British garrison held until dawn."));
		return;
	}

	if (bAnyZuluSquads && !bZuluStillToArrive && Zulu == 0 && ZuluToCome == 0)
	{
		EndMatch(EDTDFaction::British, LOCTEXT("BritishSpent", "The Zulu attack was spent before dawn."));
	}
}

TArray<ADTDCommander*> ADTDGameMode::GetCommanders(EDTDFaction Faction) const
{
	TArray<ADTDCommander*> Result;
	for (ADTDCommander* Commander : Commanders)
	{
		if (IsValid(Commander) && Commander->Faction == Faction)
		{
			Result.Add(Commander);
		}
	}
	Result.Sort([](const ADTDCommander& A, const ADTDCommander& B) { return A.SquadIndex < B.SquadIndex; });
	return Result;
}

void ADTDGameMode::EndMatch(EDTDFaction Winner, FText Reason)
{
	if (bMatchOver)
	{
		return;
	}
	bMatchOver = true;

	if (ADTDGameState* State = GetGameState<ADTDGameState>())
	{
		State->bMatchOver = true;
		State->Winner = Winner;
		State->WinReason = Reason;
	}

	OnMatchEnded(Winner, Reason);

	// Let player 1 click "Play again".
	if (APlayerController* PC = UGameplayStatics::GetPlayerController(this, 0))
	{
		PC->bShowMouseCursor = true;
		PC->SetInputMode(FInputModeGameAndUI());
	}

	if (bPauseOnMatchEnd)
	{
		UGameplayStatics::SetGamePaused(this, true);
	}
}

#undef LOCTEXT_NAMESPACE
