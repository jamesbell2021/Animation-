#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "DTDTypes.h"
#include "DTDSquadStart.generated.h"

class ADTDUnit;
class UArrowComponent;

/** Where and when a squad enters. Place one per squad; the orange arrow is the way it faces. */
UCLASS()
class DEFENDTHEDRIFT_API ADTDSquadStart : public AActor
{
	GENERATED_BODY()

public:
	ADTDSquadStart();

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD")
	EDTDFaction Faction = EDTDFaction::British;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD")
	FText SquadName;

	/** Order within its side, for Q / LB. 0 is the squad a player starts with. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD", meta = (DisplayName = "Index", ClampMin = "0"))
	int32 SquadIndex = 0;

	/** Seconds after the match starts. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD", meta = (DisplayName = "Arrival", ClampMin = "0"))
	float ArrivalSeconds = 0.f;

	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD", meta = (ClampMin = "0"))
	int32 StartingUnits = 24;

	/** Men who arrive later, in waves, at this start. */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD", meta = (ClampMin = "0"))
	int32 ReserveUnits = 0;

	/** Use this unit class instead of the commander's (e.g. BP_ZuluMarksman). */
	UPROPERTY(EditAnywhere, BlueprintReadOnly, Category = "DTD", meta = (DisplayName = "Unit Override"))
	TSubclassOf<ADTDUnit> UnitClassOverride;

private:
	UPROPERTY(VisibleAnywhere, Category = "DTD")
	TObjectPtr<USceneComponent> Root;

#if WITH_EDITORONLY_DATA
	UPROPERTY()
	TObjectPtr<UArrowComponent> Arrow;
#endif
};
