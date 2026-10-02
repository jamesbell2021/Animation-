#include "DTDUnit.h"
#include "DTDSquadComponent.h"
#include "Components/CapsuleComponent.h"
#include "Components/SkeletalMeshComponent.h"
#include "Engine/DamageEvents.h"
#include "Engine/World.h"
#include "EngineUtils.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "TimerManager.h"

namespace
{
	constexpr float ArriveRadius = 30.f;
	constexpr float MeleeCheckInterval = 0.2f;
	constexpr float ChargeSearchInterval = 0.5f;
	constexpr float MovingSpeedThreshold = 50.f;
	constexpr float TurnSpeed = 8.f;
	constexpr float MaxMeleeHeightDifference = 200.f;
}

ADTDUnit::ADTDUnit()
{
	PrimaryActorTick.bCanEverTick = true;

	// No controller: the squad drives every unit directly.
	AutoPossessAI = EAutoPossessAI::Disabled;
	AIControllerClass = nullptr;
	bUseControllerRotationPitch = false;
	bUseControllerRotationYaw = false;
	bUseControllerRotationRoll = false;

	GetCapsuleComponent()->InitCapsuleSize(34.f, 88.f);

	UCharacterMovementComponent* Move = GetCharacterMovement();
	Move->bRunPhysicsWithNoController = true;
	Move->bOrientRotationToMovement = false;
	Move->GetNavAgentPropertiesRef().bCanCrouch = true;
	Move->SetCrouchedHalfHeight(44.f);
	Move->MaxWalkSpeed = WalkSpeed;
	Move->MaxWalkSpeedCrouched = CrouchSpeed;
	Move->BrakingDecelerationWalking = 1200.f;
	Move->bUseRVOAvoidance = true;
	Move->AvoidanceConsiderationRadius = 300.f;
}

void ADTDUnit::BeginPlay()
{
	Super::BeginPlay();

	Health = MaxHealth;
	SlotLocation = GetActorLocation();
	SlotFacing = GetActorForwardVector();

	// Spread melee checks so the whole army doesn't search on the same frame.
	NextMeleeCheck = GetWorld()->GetTimeSeconds() + FMath::FRand() * MeleeCheckInterval;
}

void ADTDUnit::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	if (IsDead())
	{
		return;
	}

	const float Now = GetWorld()->GetTimeSeconds();
	if (bCharging && Now >= ChargeEndTime)
	{
		bCharging = false;
		ChargeTarget = nullptr;
	}

	UpdateStance();
	if (FollowsSlot())
	{
		UpdateMovement(Now);
		UpdateFacing(DeltaSeconds);
	}

	if (Now >= NextMeleeCheck)
	{
		NextMeleeCheck = Now + MeleeCheckInterval;
		TryMelee(Now);
	}
}

UDTDSquadComponent* ADTDUnit::GetSquad() const
{
	return OwningSquad.Get();
}

void ADTDUnit::SetSquad(UDTDSquadComponent* InSquad)
{
	OwningSquad = InSquad;
}

void ADTDUnit::SetSlot(const FVector& InLocation, const FVector& InFacing, bool bInCanFire)
{
	SlotLocation = InLocation;
	SlotFacing = InFacing.GetSafeNormal2D();
	if (SlotFacing.IsNearlyZero())
	{
		SlotFacing = GetActorForwardVector();
	}
	bSlotCanFire = bInCanFire;
}

FVector ADTDUnit::GetChestLocation() const
{
	const float Height = bIsCrouched ? ChestHeightCrouched : ChestHeightStanding;
	return GetActorLocation() + FVector(0.f, 0.f, Height);
}

void ADTDUnit::UpdateStance()
{
	bool bWantDown = false;
	if (!bCharging && State != EDTDUnitState::Presenting)
	{
		bWantDown = bHoldDown || (State == EDTDUnitState::Reloading && bKneelWhileLoading);
	}

	const bool bIsGoingDown = GetCharacterMovement()->bWantsToCrouch;
	if (bWantDown && !bIsGoingDown)
	{
		Crouch();
	}
	else if (!bWantDown && bIsGoingDown)
	{
		UnCrouch();
	}
}

void ADTDUnit::UpdateMovement(float Now)
{
	UCharacterMovementComponent* Move = GetCharacterMovement();
	Move->MaxWalkSpeed = bCharging ? ChargeSpeed : WalkSpeed;
	Move->MaxWalkSpeedCrouched = CrouchSpeed;

	FVector Goal = SlotLocation;
	float StopDistance = ArriveRadius;

	if (bCharging)
	{
		const ADTDUnit* Current = ChargeTarget.Get();
		if (Now >= NextChargeSearch || !IsLiveEnemy(this, Current))
		{
			NextChargeSearch = Now + ChargeSearchInterval;
			ChargeTarget = FindNearestEnemy(ChargeSeekRange);
		}
		if (const ADTDUnit* Target = ChargeTarget.Get())
		{
			Goal = Target->GetActorLocation();
			StopDistance = MeleeRange * 0.6f;
		}
	}

	FVector ToGoal = Goal - GetActorLocation();
	ToGoal.Z = 0.f;
	const float Distance = ToGoal.Size();
	if (Distance > StopDistance)
	{
		// Slow down on the last stretch so men settle into their slots instead of overshooting.
		AddMovementInput(ToGoal / Distance, FMath::Clamp(Distance / 150.f, 0.3f, 1.f));
	}
}

void ADTDUnit::UpdateFacing(float DeltaSeconds)
{
	FVector Direction = SlotFacing;

	const ADTDUnit* LookAt = (State == EDTDUnitState::Presenting) ? FireTarget.Get() : nullptr;
	if (!LookAt && bCharging)
	{
		LookAt = ChargeTarget.Get();
	}

	if (LookAt)
	{
		Direction = LookAt->GetActorLocation() - GetActorLocation();
	}
	else
	{
		const FVector Velocity = GetVelocity();
		if (Velocity.Size2D() > 120.f && FVector::Dist2D(SlotLocation, GetActorLocation()) > 200.f)
		{
			Direction = Velocity;
		}
	}

	Direction.Z = 0.f;
	if (!Direction.IsNearlyZero())
	{
		const FRotator Desired(0.f, Direction.Rotation().Yaw, 0.f);
		SetActorRotation(FMath::RInterpTo(GetActorRotation(), Desired, DeltaSeconds, TurnSpeed));
	}
}

bool ADTDUnit::CanFire() const
{
	return !IsDead()
		&& bSlotCanFire
		&& !bCharging
		&& State == EDTDUnitState::Ready
		&& IsLoaded();
}

bool ADTDUnit::Present(float Delay, bool bRepeatUntilEmpty)
{
	if (!CanFire())
	{
		return false;
	}

	ADTDUnit* Target = PickTarget();
	if (!Target)
	{
		return false;
	}

	FireTarget = Target;
	State = EDTDUnitState::Presenting;
	bRepeatVolley = bRepeatUntilEmpty;

	// A zero-length timer would clear itself instead of firing.
	GetWorldTimerManager().SetTimer(FireTimer, this, &ADTDUnit::FireNow, FMath::Max(Delay, 0.01f), false);
	return true;
}

void ADTDUnit::FireNow()
{
	if (IsDead())
	{
		return;
	}

	ADTDUnit* Target = FireTarget.Get();
	if (!IsLiveEnemy(this, Target) || !IsInRangeAndArc(Target))
	{
		Target = PickTarget();
	}
	FireTarget = nullptr;

	if (!Target)
	{
		// Nothing left to shoot at: stay loaded.
		State = EDTDUnitState::Ready;
		bRepeatVolley = false;
		return;
	}

	const bool bHit = FMath::FRand() < GetHitChance(Target);
	++ShotsFired;
	bLoaded = false;

	OnFired(Target, bHit);
	if (bHit)
	{
		Target->TakeDamage(RangedDamage, FDamageEvent(), nullptr, this);
	}

	if (!HasShotsLeft())
	{
		State = EDTDUnitState::OutOfShots;
		bRepeatVolley = false;
		return;
	}

	State = EDTDUnitState::Reloading;
	OnReloadStarted();
	GetWorldTimerManager().SetTimer(ReloadTimer, this, &ADTDUnit::FinishReload, FMath::Max(ReloadTime, 0.01f), false);
}

void ADTDUnit::FinishReload()
{
	if (IsDead())
	{
		return;
	}

	bLoaded = true;
	State = EDTDUnitState::Ready;

	// Thrown weapons keep throwing until the spears run out or nobody is in reach.
	if (bRepeatVolley && !Present(FMath::FRand() * VolleyStaggerMax, true))
	{
		bRepeatVolley = false;
	}
}

void ADTDUnit::StartCharge(float Duration)
{
	if (IsDead() || Duration <= 0.f)
	{
		return;
	}

	// A charge cancels a volley that hasn't fired yet.
	if (State == EDTDUnitState::Presenting)
	{
		GetWorldTimerManager().ClearTimer(FireTimer);
		State = EDTDUnitState::Ready;
		FireTarget = nullptr;
		bRepeatVolley = false;
	}

	bCharging = true;
	ChargeEndTime = GetWorld()->GetTimeSeconds() + Duration;
	NextChargeSearch = 0.f;
}

void ADTDUnit::TryMelee(float Now)
{
	if (Now < NextMeleeTime)
	{
		return;
	}

	ADTDUnit* Target = FindNearestEnemy(MeleeRange);
	if (!Target)
	{
		return;
	}

	NextMeleeTime = Now + MeleeCooldown;
	const bool bHit = FMath::FRand() < MeleeAccuracy;
	OnMeleeAttack(Target, bHit);
	if (bHit)
	{
		Target->TakeDamage(MeleeDamage, FDamageEvent(), nullptr, this);
	}
}

float ADTDUnit::TakeDamage(float DamageAmount, FDamageEvent const& DamageEvent, AController* EventInstigator, AActor* DamageCauser)
{
	if (IsDead())
	{
		return 0.f;
	}

	const float Applied = Super::TakeDamage(DamageAmount, DamageEvent, EventInstigator, DamageCauser);
	Health -= Applied;
	if (Health <= 0.f)
	{
		Die();
	}
	return Applied;
}

void ADTDUnit::Die()
{
	State = EDTDUnitState::Dead;
	bLoaded = false;
	bCharging = false;
	bRepeatVolley = false;
	FireTarget = nullptr;
	ChargeTarget = nullptr;
	GetWorldTimerManager().ClearAllTimersForObject(this);

	if (UDTDSquadComponent* MySquad = OwningSquad.Get())
	{
		MySquad->RemoveUnit(this);
	}

	GetCapsuleComponent()->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	GetCharacterMovement()->StopMovementImmediately();
	GetCharacterMovement()->DisableMovement();

	if (bRagdollOnDeath)
	{
		GetMesh()->SetCollisionProfileName(TEXT("Ragdoll"));
		GetMesh()->SetSimulatePhysics(true);
	}

	OnDied();
	SetLifeSpan(BodyLifetime);
}

bool ADTDUnit::IsLiveEnemy(const ADTDUnit* Self, const ADTDUnit* Other)
{
	return IsValid(Other) && Other != Self && !Other->IsDead() && Other->Faction != Self->Faction;
}

bool ADTDUnit::IsInRangeAndArc(const ADTDUnit* Other) const
{
	const FVector ToOther = Other->GetActorLocation() - GetActorLocation();
	if (ToOther.SizeSquared() > FMath::Square(RangedRange))
	{
		return false;
	}

	const FVector Flat = ToOther.GetSafeNormal2D();
	if (Flat.IsNearlyZero())
	{
		return true;
	}

	const float CosAngle = FVector::DotProduct(SlotFacing, Flat);
	return CosAngle >= FMath::Cos(FMath::DegreesToRadians(FireArcDegrees));
}

bool ADTDUnit::HasClearView(const ADTDUnit* Other) const
{
	// Walls and buildings are WorldStatic; units and bodies are not, so they never block.
	FCollisionQueryParams Params(SCENE_QUERY_STAT(DTDLineOfSight), false, this);
	Params.AddIgnoredActor(Other);
	return !GetWorld()->LineTraceTestByObjectType(
		GetChestLocation(), Other->GetChestLocation(), FCollisionObjectQueryParams(ECC_WorldStatic), Params);
}

float ADTDUnit::GetHitChance(const ADTDUnit* Other) const
{
	const float Distance = FVector::Dist(GetActorLocation(), Other->GetActorLocation());
	const float Alpha = FMath::Clamp(Distance / FMath::Max(RangedRange, 1.f), 0.f, 1.f);
	float Chance = FMath::Lerp(AccuracyPointBlank, AccuracyAtMaxRange, Alpha);

	if (Other->bIsCrouched)
	{
		Chance *= CrouchedHitMultiplier;
	}
	if (GetVelocity().Size2D() > MovingSpeedThreshold)
	{
		Chance *= MovingShooterMultiplier;
	}
	if (!HasClearView(Other))
	{
		Chance = bThrownWeapon ? Chance * ThrownCoverMultiplier : 0.f;
	}
	return Chance;
}

ADTDUnit* ADTDUnit::PickTarget() const
{
	TArray<ADTDUnit*> Candidates;
	for (TActorIterator<ADTDUnit> It(GetWorld()); It; ++It)
	{
		ADTDUnit* Other = *It;
		if (IsLiveEnemy(this, Other) && IsInRangeAndArc(Other))
		{
			Candidates.Add(Other);
		}
	}
	if (Candidates.Num() == 0)
	{
		return nullptr;
	}

	const FVector MyLocation = GetActorLocation();
	Candidates.Sort([&MyLocation](const ADTDUnit& A, const ADTDUnit& B)
	{
		return FVector::DistSquared(MyLocation, A.GetActorLocation()) < FVector::DistSquared(MyLocation, B.GetActorLocation());
	});
	Candidates.SetNum(FMath::Min(Candidates.Num(), FMath::Max(TargetCandidates, 1)));

	// Prefer a man in clear view; if every candidate is behind cover, shoot at one anyway.
	TArray<ADTDUnit*> InView;
	for (ADTDUnit* Candidate : Candidates)
	{
		if (HasClearView(Candidate))
		{
			InView.Add(Candidate);
		}
	}

	const TArray<ADTDUnit*>& Pool = InView.Num() > 0 ? InView : Candidates;
	return Pool[FMath::RandRange(0, Pool.Num() - 1)];
}

ADTDUnit* ADTDUnit::FindNearestEnemy(float Range) const
{
	ADTDUnit* Nearest = nullptr;
	float NearestDistSq = FMath::Square(Range);
	const FVector MyLocation = GetActorLocation();

	for (TActorIterator<ADTDUnit> It(GetWorld()); It; ++It)
	{
		ADTDUnit* Other = *It;
		if (!IsLiveEnemy(this, Other))
		{
			continue;
		}

		const FVector OtherLocation = Other->GetActorLocation();
		if (FMath::Abs(OtherLocation.Z - MyLocation.Z) > MaxMeleeHeightDifference)
		{
			continue;
		}

		const float DistSq = FVector::DistSquared2D(MyLocation, OtherLocation);
		if (DistSq <= NearestDistSq)
		{
			NearestDistSq = DistSq;
			Nearest = Other;
		}
	}
	return Nearest;
}
