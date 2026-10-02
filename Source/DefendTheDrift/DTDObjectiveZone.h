#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "DTDObjectiveZone.generated.h"

class UBoxComponent;

/** A box over the storehouse. Counts which side has men standing inside it. */
UCLASS()
class DEFENDTHEDRIFT_API ADTDObjectiveZone : public AActor
{
	GENERATED_BODY()

public:
	ADTDObjectiveZone();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "DTD")
	TObjectPtr<UBoxComponent> Box;

	UFUNCTION(BlueprintPure, Category = "DTD")
	bool IsInside(const FVector& Location) const;

	/** Living men of each side inside the box. */
	UFUNCTION(BlueprintCallable, Category = "DTD")
	void CountInside(int32& British, int32& Zulu) const;
};
