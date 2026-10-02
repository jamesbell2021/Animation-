#include "DTDPlayerController.h"
#include "DTDCommander.h"
#include "DTDGameMode.h"
#include "DTDGameState.h"
#include "DTDSharedCamera.h"
#include "DTDSquadComponent.h"
#include "EngineUtils.h"
#include "EnhancedInputComponent.h"
#include "EnhancedInputSubsystems.h"
#include "Engine/LocalPlayer.h"
#include "InputActionValue.h"
#include "InputMappingContext.h"

ADTDPlayerController::ADTDPlayerController()
{
	// The game mode points every player at the shared camera; don't let possession move the view.
	bAutoManageActiveCameraTarget = false;
}

void ADTDPlayerController::BeginPlay()
{
	Super::BeginPlay();
	AddInputMapping();
}

void ADTDPlayerController::ReceivedPlayer()
{
	Super::ReceivedPlayer();
	// Player 2 is created during play and only gets its local player after BeginPlay.
	AddInputMapping();
}

void ADTDPlayerController::AddInputMapping()
{
	if (!InputMapping)
	{
		return;
	}
	if (UEnhancedInputLocalPlayerSubsystem* Subsystem = ULocalPlayer::GetSubsystem<UEnhancedInputLocalPlayerSubsystem>(GetLocalPlayer()))
	{
		if (!Subsystem->HasMappingContext(InputMapping))
		{
			Subsystem->AddMappingContext(InputMapping, 0);
		}
	}
}

void ADTDPlayerController::SetupInputComponent()
{
	Super::SetupInputComponent();

	UEnhancedInputComponent* Input = Cast<UEnhancedInputComponent>(InputComponent.Get());
	if (!Input)
	{
		UE_LOG(LogTemp, Warning, TEXT("DTDPlayerController needs EnhancedInputComponent as the Default Input Component Class."));
		return;
	}

	// Started fires once per press.
	if (MoveAction)        { Input->BindAction(MoveAction, ETriggerEvent::Triggered, this, &ADTDPlayerController::HandleMove); }
	if (PrimaryAction)     { Input->BindAction(PrimaryAction, ETriggerEvent::Started, this, &ADTDPlayerController::HandlePrimary); }
	if (SecondaryAction)   { Input->BindAction(SecondaryAction, ETriggerEvent::Started, this, &ADTDPlayerController::HandleSecondary); }
	if (CrouchAction)      { Input->BindAction(CrouchAction, ETriggerEvent::Started, this, &ADTDPlayerController::HandleCrouch); }
	if (FormationAction)   { Input->BindAction(FormationAction, ETriggerEvent::Started, this, &ADTDPlayerController::HandleFormation); }
	if (SwitchSquadAction) { Input->BindAction(SwitchSquadAction, ETriggerEvent::Started, this, &ADTDPlayerController::HandleSwitchSquad); }
}

UDTDSquadComponent* ADTDPlayerController::GetSquad() const
{
	return IsValid(Commander) ? Commander->Squad.Get() : nullptr;
}

FText ADTDPlayerController::GetSquadName() const
{
	return IsValid(Commander) ? Commander->SquadName : FText::GetEmpty();
}

bool ADTDPlayerController::CanGiveOrders() const
{
	const ADTDGameState* State = GetWorld()->GetGameState<ADTDGameState>();
	return IsValid(Commander) && !(State && State->bMatchOver);
}

float ADTDPlayerController::GetCameraYaw()
{
	if (!SharedCamera.IsValid())
	{
		TActorIterator<ADTDSharedCamera> It(GetWorld());
		SharedCamera = It ? *It : nullptr;
	}
	return SharedCamera.IsValid() ? SharedCamera->GetViewYaw() : 0.f;
}

void ADTDPlayerController::HandleMove(const FInputActionValue& Value)
{
	if (!CanGiveOrders())
	{
		return;
	}

	// Camera-relative: "up" on the stick or W is up the screen for both players.
	const FVector2D Input = Value.Get<FVector2D>();
	const FRotationMatrix Axes(FRotator(0.f, GetCameraYaw(), 0.f));
	Commander->AddMovementInput(Axes.GetUnitAxis(EAxis::X), Input.Y);
	Commander->AddMovementInput(Axes.GetUnitAxis(EAxis::Y), Input.X);
}

void ADTDPlayerController::HandlePrimary()
{
	if (CanGiveOrders())
	{
		GetSquad()->OrderVolley();
	}
}

void ADTDPlayerController::HandleSecondary()
{
	if (CanGiveOrders())
	{
		GetSquad()->OrderCharge();
	}
}

void ADTDPlayerController::HandleCrouch()
{
	if (CanGiveOrders())
	{
		GetSquad()->ToggleGround();
	}
}

void ADTDPlayerController::HandleFormation()
{
	if (CanGiveOrders())
	{
		GetSquad()->CycleFormation();
	}
}

void ADTDPlayerController::HandleSwitchSquad()
{
	if (CanGiveOrders())
	{
		SwitchSquad();
	}
}

void ADTDPlayerController::SwitchSquad()
{
	const ADTDGameMode* GameMode = GetWorld()->GetAuthGameMode<ADTDGameMode>();
	if (!GameMode)
	{
		return;
	}

	const TArray<ADTDCommander*> Commanders = GameMode->GetCommanders(Faction);
	if (Commanders.Num() == 0)
	{
		return;
	}

	// INDEX_NONE + 1 = 0, so a player with no commander gets the first squad.
	const int32 Current = Commanders.Find(Commander);
	SetCommander(Commanders[(Current + 1) % Commanders.Num()]);
}
