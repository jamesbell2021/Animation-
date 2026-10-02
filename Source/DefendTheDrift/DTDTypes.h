#pragma once

#include "CoreMinimal.h"
#include "DTDTypes.generated.h"

UENUM(BlueprintType)
enum class EDTDFaction : uint8
{
	British,
	Zulu
};

UENUM(BlueprintType)
enum class EDTDFormation : uint8
{
	Line,	// British: 2 ranks ahead of the officer
	Square,	// British: 4 faces around the officer, facing out
	Column,	// Both: 3 wide, behind the leader
	Horns,	// Zulu: crescent, horns forward on both flanks
	Loose	// Zulu: open order, wide spacing
};

UENUM(BlueprintType)
enum class EDTDUnitState : uint8
{
	Ready,		// Loaded (or out of shots) and waiting for orders
	Presenting,	// Standing, waiting for the volley to fire
	Reloading,
	OutOfShots,	// Thrown weapons only: every spear has gone
	Dead
};
