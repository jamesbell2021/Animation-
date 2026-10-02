#include "DTDObjectiveZone.h"
#include "DTDUnit.h"
#include "Components/BoxComponent.h"
#include "EngineUtils.h"

ADTDObjectiveZone::ADTDObjectiveZone()
{
	PrimaryActorTick.bCanEverTick = false;

	Box = CreateDefaultSubobject<UBoxComponent>(TEXT("Box"));
	Box->InitBoxExtent(FVector(900.f, 700.f, 300.f));
	Box->SetCollisionEnabled(ECollisionEnabled::NoCollision);
	Box->ShapeColor = FColor(255, 140, 0);
	Box->SetHiddenInGame(true);
	RootComponent = Box;
}

bool ADTDObjectiveZone::IsInside(const FVector& Location) const
{
	const FVector Local = Box->GetComponentTransform().InverseTransformPosition(Location);
	const FVector Extent = Box->GetUnscaledBoxExtent();
	return FMath::Abs(Local.X) <= Extent.X && FMath::Abs(Local.Y) <= Extent.Y && FMath::Abs(Local.Z) <= Extent.Z;
}

void ADTDObjectiveZone::CountInside(int32& British, int32& Zulu) const
{
	British = 0;
	Zulu = 0;
	for (TActorIterator<ADTDUnit> It(GetWorld()); It; ++It)
	{
		const ADTDUnit* Unit = *It;
		if (Unit->IsDead() || !IsInside(Unit->GetActorLocation()))
		{
			continue;
		}
		(Unit->Faction == EDTDFaction::British ? British : Zulu)++;
	}
}
