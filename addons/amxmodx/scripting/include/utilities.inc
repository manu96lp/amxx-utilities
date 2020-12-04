#if defined _utilities_included
  #endinput
#endif
#define _utilities_included

/* =================================================================================
* 				[ Consts ]
* ================================================================================= */

enum _:UTILITIES_BLOCKS
{
	BLOCK_DROP 			= 0,
	BLOCK_PICKUP 		= 1,
	BLOCK_FLASHLIGHT 	= 2,
	BLOCK_SHOOT 		= 3,
	BLOCK_SPEED 		= 4,
	BLOCK_ADD_ITEMS 	= 5
}

/* =================================================================================
* 				[ Natives ]
* ================================================================================= */

/**
 * Freeze or unfreeze a player
 *
 * @param iPlayer 		Player id
 * @param bFrozen 		Freeze state
 * @param bEffects 		Particles, glow and sound
 *
 * @noreturn
 */
native UTIL_SetPlayerFrozen( const iPlayer, const bool:bFrozen, const bool:bEffects );

/**
 * Gets a player's frozen state
 *
 * @param iPlayer 		Player id
 *
 * @return 				True if frozen, false otherwise
 */
native UTIL_GetPlayerFrozen( const iPlayer );

/**
 * Gives nightvision to a player
 *
 * @note: 	State 0: Remove nightvision
 *			State 1: Give nightvision
 *			State 2: Give nightvision and turn it on
 *
 * @param iPlayer 		Player id
 * @param iState 		Nightvision state
 *
 * @noreturn
 */
native UTIL_SetPlayerNVG( const iPlayer, const iState );

/**
 * Gets a player's nightvision state
 *
 * @param iPlayer 		Player id
 *
 * @return 				0 if player doesnt have nightvision
 * 						1 if player has nightvision but hes not using it
 * 						2 if player has nightvision and hes using it
 */
native UTIL_GetPlayerNVG( const iPlayer );

/**
 * Gets a player's nightvision state
 *
 * @param iPlayer 		Player id
 * @param iBlock 		Block type
 * @param bBlock 		Block state
 *
 * @noreturn
 */
native UTIL_SetPlayerBlock( const iPlayer, const iBlock, const bool:bBlock );

/**
 * Gets a player's nightvision state
 *
 * @param iPlayer 		Player id
 * @param iBlock 		Block type
 *
 * @return 				True if blocked, false otherwise
 */
native UTIL_GetPlayerBlock( const iPlayer, const iBlock );