#include "DTDSquadStart.h"
#include "DTDUnit.h"
#include "Components/ArrowComponent.h"

ADTDSquadStart::ADTDSquadStart()
{
	PrimaryActorTick.bCanEverTick = false;

	Root = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
	RootComponent = Root;

#if WITH_EDITORONLY_DATA
	Arrow = CreateEditorOnlyDefaultSubobject<UArrowComponent>(TEXT("Arrow"));
	if (Arrow)
	{
		Arrow->SetupAttachment(Root);
		Arrow->ArrowColor = FColor(255, 140, 0);
		Arrow->ArrowSize = 3.f;
		Arrow->bIsScreenSizeScaled = true;
	}
#endif
}
