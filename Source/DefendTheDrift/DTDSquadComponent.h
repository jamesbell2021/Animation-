#pragma once

#include "CoreMinimal.h"
#include "Components/ActorComponent.h"
#include "DTDTypes.h"
#include "DTDUnit.h"
#include "DTDSquadComponent.generated.h"

/** Fired for every order, for voice lines and sound. OrderName is Volley, Charge, GroundOn, GroundOff or Formation. */
DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FDTDOrderGivenSignature, FName, OrderName);

/** Where one man should stand, which way he faces, and whether he may fire from there. */
struct FDTDSlot
{
	FVector Location = FVector::ZeroVector;
	FVector Facing = FVector::ForwardVector;
	bool bCanFire = true;
};

/**
 * Lives on a commander. Spawns the squad's units, works out formation slots around
 * the commander every frame, and passes the player's orders on to every man.
 */
UCLASS(ClassGroup = (DTD), meta = (BlueprintSpawnableComponent))
class DEFENDTHEDRIFT_API UDTDSquadComponent : public UActorComponent
{
	GENERATED_BODY()

public:
	UDTDSquadComponent();

	virtual void TickComponent(float DeltaTime, ELevelTick TickType, FActorComponentTickFunction* ThisTickFunction) override;

	// ---- Settings ----

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD")
	TSubclassOf<ADTDUnit> UnitClass;

	/** Tab / RB cycles through these in order. The first is the starting formation. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD")
	TArray<EDTDFormation> AvailableFormations;

	/** Distance between neighbouring men, in cm. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD", meta = (ClampMin = "50"))
	float Spacing = 130.f;

	/** Seconds between the order ("Present!") and the volley. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD", meta = (ClampMin = "0"))
	float PresentDelay = 0.6f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD", meta = (ClampMin = "0"))
	float ChargeDuration = 3.f;

	/** Seconds from the start of one charge until the next is allowed. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD", meta = (ClampMin = "0"))
	float ChargeCooldown = 15.f;

	/** Set by the Squad Start this squad arrives from. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD", meta = (ClampMin = "0"))
	int32 StartingUnits = 0;

	/** Men still to come. Set by the Squad Start; the game mode sends them in waves. */
	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	int32 ReserveUnits = 0;

	UPROPERTY(BlueprintAssignable, Category = "DTD")
	FDTDOrderGivenSignature OnOrderGiven;

	// ---- Orders ----

	/** Every loaded man with a target in his arc stands and fires. Returns how many will fire. */
	UFUNCTION(BlueprintCallable, Category = "DTD")
	int32 OrderVolley();

	/** Returns false while the charge is cooling down. */
	UFUNCTION(BlueprintCallable, Category = "DTD")
	bool OrderCharge();

	/** Down! / To ground: stay crouched except to fire. */
	UFUNCTION(BlueprintCallable, Category = "DTD")
	void ToggleGround();

	UFUNCTION(BlueprintCallable, Category = "DTD")
	void CycleFormation();

	UFUNCTION(BlueprintCallable, Category = "DTD")
	void SetFormation(EDTDFormation NewFormation);

	/** Spawn men into the squad. bAtEntry spawns them at the squad's entry point (reserves); otherwise in formation around the commander. Returns how many spawned. */
	UFUNCTION(BlueprintCallable, Category = "DTD")
	int32 SpawnUnits(int32 Count, bool bAtEntry);

	// ---- Queries ----

	UFUNCTION(BlueprintPure, Category = "DTD")
	int32 GetLoadedCount() const;

	UFUNCTION(BlueprintPure, Category = "DTD")
	int32 GetUnitCount() const;

	UFUNCTION(BlueprintPure, Category = "DTD")
	EDTDFormation GetCurrentFormation() const { return CurrentFormation; }

	UFUNCTION(BlueprintPure, Category = "DTD")
	bool IsGrounded() const { return bGrounded; }

	UFUNCTION(BlueprintPure, Category = "DTD")
	float GetChargeCooldownRemaining() const;

	UFUNCTION(BlueprintPure, Category = "DTD")
	EDTDFaction GetFaction() const;

	UFUNCTION(BlueprintPure, Category = "DTD")
	FText GetSquadName() const;

	UFUNCTION(BlueprintPure, Category = "DTD")
	TArray<ADTDUnit*> GetUnits() const;

	void RemoveUnit(ADTDUnit* Unit);

	/** Where reserves appear: the Squad Start, at the commander's spawn height. */
	void SetEntry(const FTransform& InEntry) { EntryTransform = InEntry; }

protected:
	virtual void BeginPlay() override;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	EDTDFormation CurrentFormation = EDTDFormation::Line;

	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	bool bGrounded = false;

private:
	void ComputeSlots(int32 Count, const FVector& Origin, float Yaw, TArray<FDTDSlot>& OutSlots) const;

	UPROPERTY(Transient)
	TArray<TObjectPtr<ADTDUnit>> Units;

	FTransform EntryTransform = FTransform::Identity;
	float NextChargeTime = 0.f;
};
