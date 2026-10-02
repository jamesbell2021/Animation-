#include "DTDCommander.h"
#include "DTDSquadComponent.h"
#include "Components/CapsuleComponent.h"
#include "GameFramework/CharacterMovementComponent.h"

ADTDCommander::ADTDCommander()
{
	Squad = CreateDefaultSubobject<UDTDSquadComponent>(TEXT("Squad"));

	// Losing him loses the match, so he takes a few hits rather than one.
	MaxHealth = 300.f;
	WalkSpeed = 300.f;

	// Walk through his own men rather than shoving them out of their slots.
	GetCapsuleComponent()->SetCollisionResponseToChannel(ECC_Pawn, ECR_Ignore);

	// The player controller moves him; he turns to face the way he walks.
	UCharacterMovementComponent* Move = GetCharacterMovement();
	Move->bOrientRotationToMovement = true;
	Move->RotationRate = FRotator(0.f, 540.f, 0.f);
	Move->bUseRVOAvoidance = false;
	Move->MaxWalkSpeed = WalkSpeed;
}

void ADTDCommander::BeginPlay()
{
	Super::BeginPlay();
	GetCharacterMovement()->MaxWalkSpeed = WalkSpeed;
	GetCharacterMovement()->MaxWalkSpeedCrouched = CrouchSpeed;
}
