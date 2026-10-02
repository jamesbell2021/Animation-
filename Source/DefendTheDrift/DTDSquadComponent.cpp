#include "DTDSquadComponent.h"
#include "DTDCommander.h"
#include "Engine/World.h"

DEFINE_LOG_CATEGORY_STATIC(LogDTDSquad, Log, All);

UDTDSquadComponent::UDTDSquadComponent()
{
	PrimaryComponentTick.bCanEverTick = true;
	AvailableFormations = { EDTDFormation::Line, EDTDFormation::Square, EDTDFormation::Column };
}

void UDTDSquadComponent::BeginPlay()
{
	Super::BeginPlay();

	if (AvailableFormations.Num() > 0)
	{
		CurrentFormation = AvailableFormations[0];
	}
}

void UDTDSquadComponent::TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction)
{
	Super::TickComponent(DeltaTime, TickType, ThisTickFunction);

	Units.RemoveAll([](const TObjectPtr<ADTDUnit>& Unit) { return !IsValid(Unit) || Unit->IsDead(); });
	if (Units.Num() == 0)
	{
		return;
	}

	const AActor* Owner = GetOwner();
	TArray<FDTDSlot> Slots;
	ComputeSlots(Units.Num(), Owner->GetActorLocation(), Owner->GetActorRotation().Yaw, Slots);

	for (int32 Index = 0; Index < Units.Num(); ++Index)
	{
		Units[Index]->SetSlot(Slots[Index].Location, Slots[Index].Facing, Slots[Index].bCanFire);
	}
}

int32 UDTDSquadComponent::SpawnUnits(int32 Count, bool bAtEntry)
{
	if (Count <= 0)
	{
		return 0;
	}
	if (!UnitClass)
	{
		UE_LOG(LogDTDSquad, Warning, TEXT("Squad has no UnitClass set (%s)"), *GetNameSafe(GetOwner()));
		return 0;
	}

	UWorld* World = GetWorld();
	AActor* Owner = GetOwner();
	const FVector Origin = bAtEntry ? EntryTransform.GetLocation() : Owner->GetActorLocation();
	const float Yaw = bAtEntry ? EntryTransform.Rotator().Yaw : Owner->GetActorRotation().Yaw;

	TArray<FDTDSlot> Slots;
	ComputeSlots(Count, Origin, Yaw, Slots);

	int32 Spawned = 0;
	for (const FDTDSlot& Slot : Slots)
	{
		const FTransform SpawnTransform(Slot.Facing.Rotation(), Slot.Location);
		ADTDUnit* Unit = World->SpawnActorDeferred<ADTDUnit>(
			UnitClass, SpawnTransform, Owner, nullptr, ESpawnActorCollisionHandlingMethod::AdjustIfPossibleButAlwaysSpawn);
		if (!Unit)
		{
			continue;
		}

		Unit->Faction = GetFaction();
		Unit->SetSquad(this);
		Unit->FinishSpawning(SpawnTransform);
		Unit->SetHoldDown(bGrounded);
		Units.Add(Unit);
		++Spawned;
	}
	return Spawned;
}

int32 UDTDSquadComponent::OrderVolley()
{
	int32 Firing = 0;
	for (ADTDUnit* Unit : Units)
	{
		if (IsValid(Unit) && Unit->Present(PresentDelay + FMath::FRand() * Unit->VolleyStaggerMax, Unit->bThrownWeapon))
		{
			++Firing;
		}
	}

	OnOrderGiven.Broadcast(TEXT("Volley"));
	return Firing;
}

bool UDTDSquadComponent::OrderCharge()
{
	const float Now = GetWorld()->GetTimeSeconds();
	if (Now < NextChargeTime)
	{
		return false;
	}
	NextChargeTime = Now + ChargeCooldown;

	for (ADTDUnit* Unit : Units)
	{
		if (IsValid(Unit))
		{
			Unit->StartCharge(ChargeDuration);
		}
	}

	OnOrderGiven.Broadcast(TEXT("Charge"));
	return true;
}

void UDTDSquadComponent::ToggleGround()
{
	bGrounded = !bGrounded;
	for (ADTDUnit* Unit : Units)
	{
		if (IsValid(Unit))
		{
			Unit->SetHoldDown(bGrounded);
		}
	}

	OnOrderGiven.Broadcast(bGrounded ? FName(TEXT("GroundOn")) : FName(TEXT("GroundOff")));
}

void UDTDSquadComponent::CycleFormation()
{
	if (AvailableFormations.Num() == 0)
	{
		return;
	}

	// INDEX_NONE + 1 = 0, so an unknown formation goes back to the first one.
	const int32 Current = AvailableFormations.Find(CurrentFormation);
	SetFormation(AvailableFormations[(Current + 1) % AvailableFormations.Num()]);
}

void UDTDSquadComponent::SetFormation(EDTDFormation NewFormation)
{
	CurrentFormation = NewFormation;
	OnOrderGiven.Broadcast(TEXT("Formation"));
}

int32 UDTDSquadComponent::GetLoadedCount() const
{
	int32 Count = 0;
	for (const ADTDUnit* Unit : Units)
	{
		if (IsValid(Unit) && Unit->IsLoaded())
		{
			++Count;
		}
	}
	return Count;
}

int32 UDTDSquadComponent::GetUnitCount() const
{
	int32 Count = 0;
	for (const ADTDUnit* Unit : Units)
	{
		if (IsValid(Unit) && !Unit->IsDead())
		{
			++Count;
		}
	}
	return Count;
}

float UDTDSquadComponent::GetChargeCooldownRemaining() const
{
	return FMath::Max(0.f, NextChargeTime - GetWorld()->GetTimeSeconds());
}

EDTDFaction UDTDSquadComponent::GetFaction() const
{
	const ADTDCommander* Commander = Cast<ADTDCommander>(GetOwner());
	return Commander ? Commander->Faction : EDTDFaction::British;
}

FText UDTDSquadComponent::GetSquadName() const
{
	const ADTDCommander* Commander = Cast<ADTDCommander>(GetOwner());
	return Commander ? Commander->SquadName : FText::GetEmpty();
}

TArray<ADTDUnit*> UDTDSquadComponent::GetUnits() const
{
	TArray<ADTDUnit*> Result;
	for (ADTDUnit* Unit : Units)
	{
		if (IsValid(Unit) && !Unit->IsDead())
		{
			Result.Add(Unit);
		}
	}
	return Result;
}

void UDTDSquadComponent::RemoveUnit(ADTDUnit* Unit)
{
	Units.Remove(Unit);
}

void UDTDSquadComponent::ComputeSlots(int32 Count, const FVector& Origin, float Yaw, TArray<FDTDSlot>& OutSlots) const
{
	OutSlots.SetNum(Count);
	if (Count <= 0)
	{
		return;
	}

	const FRotator Rotation(0.f, Yaw, 0.f);
	const FRotationMatrix Axes(Rotation);
	const FVector Forward = Axes.GetUnitAxis(EAxis::X);
	const FVector Right = Axes.GetUnitAxis(EAxis::Y);
	const float S = Spacing;

	// Lateral offset that centres Count items with the given gap.
	auto Centred = [](int32 Index, int32 InRow, float Gap) { return (Index - (InRow - 1) * 0.5f) * Gap; };

	switch (CurrentFormation)
	{
	case EDTDFormation::Line:
	{
		// Two ranks ahead of the officer, everyone facing forward.
		const int32 PerRank = FMath::DivideAndRoundUp(Count, 2);
		for (int32 i = 0; i < Count; ++i)
		{
			const int32 Rank = i / PerRank;
			const int32 InRank = FMath::Min(PerRank, Count - Rank * PerRank);
			OutSlots[i].Location = Origin + Forward * ((2 - Rank) * S) + Right * Centred(i % PerRank, InRank, S);
			OutSlots[i].Facing = Forward;
		}
		break;
	}

	case EDTDFormation::Square:
	{
		// Four faces around the officer, each facing out: front, right, back, left.
		const int32 PerFace = FMath::DivideAndRoundUp(Count, 4);
		const float HalfSide = FMath::Max(PerFace, 2) * S * 0.5f + S * 0.5f;
		const FVector Out[4] = { Forward, Right, -Forward, -Right };
		const FVector Along[4] = { Right, -Forward, -Right, Forward };
		for (int32 i = 0; i < Count; ++i)
		{
			const int32 Face = i / PerFace;
			const int32 InFace = FMath::Min(PerFace, Count - Face * PerFace);
			OutSlots[i].Location = Origin + Out[Face] * HalfSide + Along[Face] * Centred(i % PerFace, InFace, S);
			OutSlots[i].Facing = Out[Face];
		}
		break;
	}

	case EDTDFormation::Column:
	{
		// Three wide behind the leader. Only the head of the column can fire.
		constexpr int32 Width = 3;
		for (int32 i = 0; i < Count; ++i)
		{
			const int32 Row = i / Width;
			const int32 InRow = FMath::Min(Width, Count - Row * Width);
			OutSlots[i].Location = Origin - Forward * ((Row + 1) * S) + Right * Centred(i % Width, InRow, S);
			OutSlots[i].Facing = Forward;
			OutSlots[i].bCanFire = (Row == 0);
		}
		break;
	}

	case EDTDFormation::Horns:
	{
		// A crescent: the chest in the centre, the horns pushed forward on both flanks and turned inward.
		const int32 Rows = Count > 24 ? 2 : 1;
		const int32 PerRow = FMath::DivideAndRoundUp(Count, Rows);
		const float HornDepth = (PerRow - 1) * S * 0.35f;
		for (int32 i = 0; i < Count; ++i)
		{
			const int32 Row = i / PerRow;
			const int32 InRow = FMath::Min(PerRow, Count - Row * PerRow);
			const int32 Col = i % PerRow;
			const float T = InRow > 1 ? (Col / float(InRow - 1)) * 2.f - 1.f : 0.f; // -1 left horn .. +1 right horn
			const float Ahead = 2.f * S - Row * S + HornDepth * T * T;
			OutSlots[i].Location = Origin + Forward * Ahead + Right * Centred(Col, InRow, S);
			OutSlots[i].Facing = FRotator(0.f, Yaw - T * 35.f, 0.f).Vector();
		}
		break;
	}

	case EDTDFormation::Loose:
	default:
	{
		// Open order: a wide grid ahead of the induna, nudged so it doesn't look drilled.
		const float Gap = S * 2.f;
		const int32 Cols = FMath::Max(1, FMath::CeilToInt(FMath::Sqrt(Count * 1.5f)));
		const int32 Rows = FMath::DivideAndRoundUp(Count, Cols);
		for (int32 i = 0; i < Count; ++i)
		{
			const int32 Row = i / Cols;
			const int32 InRow = FMath::Min(Cols, Count - Row * Cols);
			const float JitterA = FMath::Frac(FMath::Sin(i * 12.9898f) * 43758.5453f) - 0.5f;
			const float JitterB = FMath::Frac(FMath::Sin(i * 78.233f) * 12345.6789f) - 0.5f;
			const float Ahead = S + (Rows - 1 - Row) * Gap + JitterA * S * 0.5f;
			OutSlots[i].Location = Origin + Forward * Ahead + Right * (Centred(i % Cols, InRow, Gap) + JitterB * S * 0.5f);
			OutSlots[i].Facing = Forward;
		}
		break;
	}
	}
}
