#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "DTDTypes.h"
#include "DTDCommander.generated.h"

class UDTDSquadComponent;

/**
 * One per squad: the officer or induna a player drives. The squad forms up around him.
 * Commanders are not units, so nobody targets them.
 */
UCLASS()
class DEFENDTHEDRIFT_API ADTDCommander : public ACharacter
{
	GENERATED_BODY()

public:
	ADTDCommander();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "DTD")
	TObjectPtr<UDTDSquadComponent> Squad;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD")
	EDTDFaction Faction = EDTDFaction::British;

	/** "Lieutenant", "Induna"... */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD")
	FText CommanderTitle;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD", meta = (ClampMin = "0"))
	float WalkSpeed = 300.f;

	/** Set from the Squad Start he arrived at. */
	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	FText SquadName;

	/** Order within his side; Q / LB goes to the next index. */
	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	int32 SquadIndex = 0;

protected:
	virtual void BeginPlay() override;
};
