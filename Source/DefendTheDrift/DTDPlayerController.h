#pragma once

#include "CoreMinimal.h"
#include "GameFramework/PlayerController.h"
#include "DTDCommander.h"
#include "DTDTypes.h"
#include "DTDPlayerController.generated.h"

class ADTDSharedCamera;
class UDTDSquadComponent;
class UInputAction;
class UInputMappingContext;
struct FInputActionValue;

/**
 * Turns Enhanced Input into squad orders. Drives one commander of its side at a time
 * without possessing him; the view stays on the shared camera.
 */
UCLASS()
class DEFENDTHEDRIFT_API ADTDPlayerController : public APlayerController
{
	GENERATED_BODY()

public:
	ADTDPlayerController();

	virtual void ReceivedPlayer() override;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD|Input")
	TObjectPtr<UInputMappingContext> InputMapping;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD|Input")
	TObjectPtr<UInputAction> MoveAction;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD|Input")
	TObjectPtr<UInputAction> PrimaryAction;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD|Input")
	TObjectPtr<UInputAction> SecondaryAction;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD|Input")
	TObjectPtr<UInputAction> CrouchAction;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD|Input")
	TObjectPtr<UInputAction> FormationAction;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD|Input")
	TObjectPtr<UInputAction> SwitchSquadAction;

	UFUNCTION(BlueprintPure, Category = "DTD")
	ADTDCommander* GetCommander() const { return Commander; }

	UFUNCTION(BlueprintPure, Category = "DTD")
	UDTDSquadComponent* GetSquad() const;

	UFUNCTION(BlueprintPure, Category = "DTD")
	FText GetSquadName() const;

	UFUNCTION(BlueprintPure, Category = "DTD")
	EDTDFaction GetFaction() const { return Faction; }

	void SetFaction(EDTDFaction InFaction) { Faction = InFaction; }

	UFUNCTION(BlueprintCallable, Category = "DTD")
	void SetCommander(ADTDCommander* NewCommander) { Commander = NewCommander; }

	/** Pass command to the next squad of this side that has arrived. */
	UFUNCTION(BlueprintCallable, Category = "DTD")
	void SwitchSquad();

protected:
	virtual void BeginPlay() override;
	virtual void SetupInputComponent() override;

private:
	void AddInputMapping();
	bool CanGiveOrders() const;
	float GetCameraYaw();

	void HandleMove(const FInputActionValue& Value);
	void HandlePrimary();
	void HandleSecondary();
	void HandleCrouch();
	void HandleFormation();
	void HandleSwitchSquad();

	UPROPERTY(VisibleInstanceOnly, Category = "DTD")
	EDTDFaction Faction = EDTDFaction::British;

	UPROPERTY(VisibleInstanceOnly, Transient, Category = "DTD")
	TObjectPtr<ADTDCommander> Commander;

	TWeakObjectPtr<ADTDSharedCamera> SharedCamera;
};
