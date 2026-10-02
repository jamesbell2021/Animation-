#pragma once

#include "CoreMinimal.h"
#include "DTDUnit.h"
#include "DTDCommander.generated.h"

class UDTDSquadComponent;

/**
 * One per squad: the officer or induna a player drives. The squad forms up around him.
 * He is a unit himself, so he can be shot and fights anyone who reaches him.
 * If any commander falls, his side loses the match.
 */
UCLASS()
class DEFENDTHEDRIFT_API ADTDCommander : public ADTDUnit
{
	GENERATED_BODY()

public:
	ADTDCommander();

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "DTD")
	TObjectPtr<UDTDSquadComponent> Squad;

	/** "Lieutenant", "Induna"... */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD")
	FText CommanderTitle;

	/** Set from the Squad Start he arrived at. */
	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	FText SquadName;

	/** Order within his side; Q / LB goes to the next index. */
	UPROPERTY(VisibleInstanceOnly, BlueprintReadOnly, Category = "DTD")
	int32 SquadIndex = 0;

protected:
	virtual void BeginPlay() override;
	virtual bool FollowsSlot() const override { return false; }
};
