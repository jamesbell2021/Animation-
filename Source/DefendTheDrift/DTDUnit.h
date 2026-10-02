#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "DTDTypes.h"
#include "DTDUnit.generated.h"

class UDTDSquadComponent;

/**
 * One man: stance, volley, fire arc, reload, targeting, melee, death.
 * Units have no controller; their squad gives them a slot and orders every frame.
 */
UCLASS()
class DEFENDTHEDRIFT_API ADTDUnit : public ACharacter
{
	GENERATED_BODY()

public:
	ADTDUnit();

	virtual void Tick(float DeltaSeconds) override;
	virtual float TakeDamage(float DamageAmount, struct FDamageEvent const& DamageEvent, AController* EventInstigator, AActor* DamageCauser) override;

	// ---- Settings ----

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD")
	EDTDFaction Faction = EDTDFaction::British;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD", meta = (ClampMin = "1"))
	float MaxHealth = 100.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged", meta = (ClampMin = "0"))
	float RangedRange = 3000.f;

	/** Hit chance at point-blank range, before modifiers. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged", meta = (ClampMin = "0", ClampMax = "1"))
	float AccuracyPointBlank = 0.45f;

	/** Hit chance at Ranged Range, before modifiers. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged", meta = (ClampMin = "0", ClampMax = "1"))
	float AccuracyAtMaxRange = 0.15f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged", meta = (ClampMin = "0"))
	float RangedDamage = 100.f;

	/** Seconds to load the next shot (or ready the next spear). */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged", meta = (ClampMin = "0"))
	float ReloadTime = 5.f;

	/** Shots carried. -1 = unlimited. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged")
	int32 MaxShots = -1;

	/** Each man fires up to this many seconds after the Present delay, so a volley is near-simultaneous. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged", meta = (ClampMin = "0"))
	float VolleyStaggerMax = 0.1f;

	/** Thrown spears arc: a wall halves their chance instead of blocking them, and one order throws every spear. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged")
	bool bThrownWeapon = false;

	/** Kneel after firing and stay down until loaded. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged")
	bool bKneelWhileLoading = true;

	/** Fires only at enemies within this many degrees either side of the way his slot faces. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged", meta = (ClampMin = "0", ClampMax = "180"))
	float FireArcDegrees = 75.f;

	/** Each shot picks one of this many nearest enemies in range and arc. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged", meta = (ClampMin = "1"))
	int32 TargetCandidates = 6;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged", meta = (ClampMin = "0", ClampMax = "1"))
	float CrouchedHitMultiplier = 0.4f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged", meta = (ClampMin = "0", ClampMax = "1"))
	float MovingShooterMultiplier = 0.5f;

	/** Thrown weapons only: chance multiplier when a wall is in the way. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Ranged", meta = (ClampMin = "0", ClampMax = "1"))
	float ThrownCoverMultiplier = 0.5f;

	/** Melee starts automatically when an enemy is this close. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Melee", meta = (ClampMin = "0"))
	float MeleeRange = 170.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Melee", meta = (ClampMin = "0"))
	float MeleeDamage = 50.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Melee", meta = (ClampMin = "0", ClampMax = "1"))
	float MeleeAccuracy = 0.5f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Melee", meta = (ClampMin = "0.1"))
	float MeleeCooldown = 1.5f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Movement", meta = (ClampMin = "0"))
	float WalkSpeed = 380.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Movement", meta = (ClampMin = "0"))
	float CrouchSpeed = 160.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Movement", meta = (ClampMin = "0"))
	float ChargeSpeed = 520.f;

	/** When charging, runs at the nearest enemy within this distance. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Movement", meta = (ClampMin = "0"))
	float ChargeSeekRange = 700.f;

	/** Chest height above the capsule centre, used for line of sight. Standing chest is about 141 cm off the ground. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Sight")
	float ChestHeightStanding = 53.f;

	/** Kneeling chest is about 64 cm off the ground, below a 110 cm wall. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Sight")
	float ChestHeightCrouched = 20.f;

	/** Seconds a body stays before it is removed. Fade the material in On Died. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Death", meta = (ClampMin = "0.1"))
	float BodyLifetime = 6.f;

	/** Let the body fall as a ragdoll. Turn off once On Died plays a fall montage. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD|Death")
	bool bRagdollOnDeath = true;

	// ---- Events for Blueprints (effects, sound, animation) ----

	UFUNCTION(BlueprintImplementableEvent, Category = "DTD")
	void OnFired(ADTDUnit* Target, bool bHit);

	UFUNCTION(BlueprintImplementableEvent, Category = "DTD")
	void OnReloadStarted();

	UFUNCTION(BlueprintImplementableEvent, Category = "DTD")
	void OnMeleeAttack(ADTDUnit* Target, bool bHit);

	UFUNCTION(BlueprintImplementableEvent, Category = "DTD")
	void OnDied();

	// ---- Queries ----

	UFUNCTION(BlueprintPure, Category = "DTD")
	bool IsDead() const { return State == EDTDUnitState::Dead; }

	/** Loaded and with shots left. */
	UFUNCTION(BlueprintPure, Category = "DTD")
	bool IsLoaded() const { return bLoaded && HasShotsLeft() && !IsDead(); }

	UFUNCTION(BlueprintPure, Category = "DTD")
	bool IsCharging() const { return bCharging; }

	UFUNCTION(BlueprintPure, Category = "DTD")
	EDTDUnitState GetUnitState() const { return State; }

	UFUNCTION(BlueprintPure, Category = "DTD")
	float GetHealth() const { return Health; }

	UFUNCTION(BlueprintPure, Category = "DTD")
	UDTDSquadComponent* GetSquad() const;

	FVector GetChestLocation() const;

	// ---- Orders (from the squad) ----

	void SetSquad(UDTDSquadComponent* InSquad);
	void SetSlot(const FVector& InLocation, const FVector& InFacing, bool bInCanFire);
	void SetHoldDown(bool bInHoldDown) { bHoldDown = bInHoldDown; }

	/** Stand and fire after Delay seconds. Returns false if this man can't fire (not loaded, no target in arc...). */
	bool Present(float Delay, bool bRepeatUntilEmpty);

	void StartCharge(float Duration);

	/** True if he could join a volley right now. */
	bool CanFire() const;

protected:
	virtual void BeginPlay() override;

	/** False for a unit a player moves himself (the commander): he doesn't walk to a slot or turn to its facing. */
	virtual bool FollowsSlot() const { return true; }

private:
	void UpdateStance();
	void UpdateMovement(float Now);
	void UpdateFacing(float DeltaSeconds);
	void TryMelee(float Now);
	void FireNow();
	void FinishReload();
	void Die();

	bool HasShotsLeft() const { return MaxShots < 0 || ShotsFired < MaxShots; }
	bool IsInRangeAndArc(const ADTDUnit* Other) const;
	bool HasClearView(const ADTDUnit* Other) const;
	float GetHitChance(const ADTDUnit* Other) const;
	ADTDUnit* PickTarget() const;
	ADTDUnit* FindNearestEnemy(float Range) const;
	static bool IsLiveEnemy(const ADTDUnit* Self, const ADTDUnit* Other);

	UPROPERTY(VisibleInstanceOnly, Category = "DTD|State")
	EDTDUnitState State = EDTDUnitState::Ready;

	UPROPERTY(VisibleInstanceOnly, Category = "DTD|State")
	float Health = 100.f;

	UPROPERTY(VisibleInstanceOnly, Category = "DTD|State")
	bool bLoaded = true;

	UPROPERTY(VisibleInstanceOnly, Category = "DTD|State")
	int32 ShotsFired = 0;

	UPROPERTY(VisibleInstanceOnly, Category = "DTD|State")
	bool bCharging = false;

	UPROPERTY(VisibleInstanceOnly, Category = "DTD|State")
	bool bHoldDown = false;

	TWeakObjectPtr<UDTDSquadComponent> OwningSquad;
	TWeakObjectPtr<ADTDUnit> FireTarget;
	TWeakObjectPtr<ADTDUnit> ChargeTarget;

	FVector SlotLocation = FVector::ZeroVector;
	FVector SlotFacing = FVector::ForwardVector;
	bool bSlotCanFire = true;
	bool bRepeatVolley = false;

	float ChargeEndTime = 0.f;
	float NextChargeSearch = 0.f;
	float NextMeleeCheck = 0.f;
	float NextMeleeTime = 0.f;

	FTimerHandle FireTimer;
	FTimerHandle ReloadTimer;
};
