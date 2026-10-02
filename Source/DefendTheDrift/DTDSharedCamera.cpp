#include "DTDSharedCamera.h"
#include "DTDCommander.h"
#include "DTDPlayerController.h"
#include "Camera/CameraComponent.h"
#include "Engine/World.h"

ADTDSharedCamera::ADTDSharedCamera()
{
	PrimaryActorTick.bCanEverTick = true;
	// Follow the commanders after they have moved this frame.
	PrimaryActorTick.TickGroup = TG_PostPhysics;

	Camera = CreateDefaultSubobject<UCameraComponent>(TEXT("Camera"));
	Camera->SetFieldOfView(60.f);
	RootComponent = Camera;
}

void ADTDSharedCamera::BeginPlay()
{
	Super::BeginPlay();

	ViewYaw = GetActorRotation().Yaw;
	SetActorRotation(FRotator(Pitch, ViewYaw, 0.f));
}

void ADTDSharedCamera::Tick(float DeltaSeconds)
{
	Super::Tick(DeltaSeconds);

	FVector Sum = FVector::ZeroVector;
	TArray<FVector, TInlineAllocator<2>> Points;
	for (FConstPlayerControllerIterator It = GetWorld()->GetPlayerControllerIterator(); It; ++It)
	{
		const ADTDPlayerController* PC = Cast<ADTDPlayerController>(It->Get());
		const ADTDCommander* Commander = PC ? PC->GetCommander() : nullptr;
		if (IsValid(Commander))
		{
			Points.Add(Commander->GetActorLocation());
			Sum += Commander->GetActorLocation();
		}
	}
	if (Points.Num() == 0)
	{
		return;
	}

	float Separation = 0.f;
	for (int32 A = 0; A < Points.Num(); ++A)
	{
		for (int32 B = A + 1; B < Points.Num(); ++B)
		{
			Separation = FMath::Max(Separation, FVector::Dist(Points[A], Points[B]));
		}
	}

	const FVector DesiredFocus = Sum / Points.Num();
	const float DesiredDistance = FMath::Clamp(MinDistance + Separation * DistancePerSeparation, MinDistance, MaxDistance);

	if (!bHasFocus)
	{
		Focus = DesiredFocus;
		Distance = DesiredDistance;
		bHasFocus = true;
	}
	else
	{
		Focus = FMath::VInterpTo(Focus, DesiredFocus, DeltaSeconds, FollowSpeed);
		Distance = FMath::FInterpTo(Distance, DesiredDistance, DeltaSeconds, FollowSpeed);
	}

	const FRotator ViewRotation(Pitch, ViewYaw, 0.f);
	SetActorLocationAndRotation(Focus - ViewRotation.Vector() * Distance, ViewRotation);
}
