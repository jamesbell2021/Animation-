#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "DTDSharedCamera.generated.h"

class UCameraComponent;

/**
 * One couch camera framing the two commanders being driven. Its yaw is the way it was
 * placed in the level; "up" on the stick or W moves that way for both players.
 */
UCLASS()
class DEFENDTHEDRIFT_API ADTDSharedCamera : public AActor
{
	GENERATED_BODY()

public:
	ADTDSharedCamera();

	virtual void Tick(float DeltaSeconds) override;

	UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "DTD")
	TObjectPtr<UCameraComponent> Camera;

	/** Degrees below the horizon. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD", meta = (ClampMin = "-89", ClampMax = "-10"))
	float Pitch = -60.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD", meta = (ClampMin = "0"))
	float MinDistance = 2500.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD", meta = (ClampMin = "0"))
	float MaxDistance = 6500.f;

	/** Extra camera distance per cm between the two commanders. */
	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD", meta = (ClampMin = "0"))
	float DistancePerSeparation = 1.f;

	UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "DTD", meta = (ClampMin = "0"))
	float FollowSpeed = 4.f;

	UFUNCTION(BlueprintPure, Category = "DTD")
	float GetViewYaw() const { return ViewYaw; }

protected:
	virtual void BeginPlay() override;

private:
	float ViewYaw = 0.f;
	FVector Focus = FVector::ZeroVector;
	float Distance = 0.f;
	bool bHasFocus = false;
};
