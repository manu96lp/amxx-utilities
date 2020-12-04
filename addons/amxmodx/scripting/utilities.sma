#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <reapi>
#include <xs>

#include <common>
#include <utilities>

/* =================================================================================
* 				[ Initiation & Global Variables ]
* ================================================================================= */

const CSW_NOT_WEAPON = ( ( 1 << 0 ) | ( 1 << 2 ) | ( 1 << 6 ) | ( 1 << 31 ) | ( 1 << 32 ) );

const Float:DEFAULT_SPEED = 250.0;

enum _:Player_Struct
{
	Player_Model[ 32 ],
	
	Float:Player_Still_Time,
	Float:Player_Still_Origin[ 3 ],
	Float:Player_Still_Angles[ 3 ]
}

new const g_szNightVisionOnSound[ ] 	= "items/nvg_on.wav";
new const g_szNightVisionOffSound[ ] 	= "items/nvg_off.wav";

new const g_szFreezeSound[ ] 			= "player_freeze.wav";
new const g_szUnfreezeSound[ ] 			= "player_unfreeze.wav";

new g_iIsConnected;
new g_iIsAlive;

new g_iIsFrozen;
new g_iIsModelled;
new g_iIsNightVisionOn;

new g_iHasNightVision;
new g_iHasBlock[ UTILITIES_BLOCKS ];

new g_pCvarLightStyle;

new HamHook:g_hResetMaxSpeed;
new HamHook:g_hImpulse;
new HamHook:g_hAddItem;
new HamHook:g_hWeaponTouch;
new HamHook:g_hArmouryTouch;
new HamHook:g_hUseGameEquip;
new HamHook:g_hUseWeaponStrip;
new HamHook:g_hDeploy[ MAX_WEAPONS ];

new g_sPlayers[ PLAYER_ARRAY ][ Player_Struct ];

/* =================================================================================
* 				[ Plugin Events ]
* ================================================================================= */

public plugin_natives( )
{
	register_native( "UTIL_SetPlayerBlock", "_UTIL_SetPlayerBlock" );
	register_native( "UTIL_GetPlayerBlock", "_UTIL_GetPlayerBlock" );
	
	register_native( "UTIL_SetPlayerFrozen", "_UTIL_SetPlayerFrozen" );
	register_native( "UTIL_GetPlayerFrozen", "_UTIL_GetPlayerFrozen" );
	
	register_native( "UTIL_SetPlayerNVG", "_UTIL_SetPlayerNVG" );
	register_native( "UTIL_GetPlayerNVG", "_UTIL_GetPlayerNVG" );
}

public plugin_precache( )
{
	precache_sound( g_szNightVisionOnSound );
	precache_sound( g_szNightVisionOffSound );
	
	precache_sound( g_szFreezeSound );
	precache_sound( g_szUnfreezeSound );
}

public plugin_init( )
{
	register_plugin( "Utilities", "1.1", "Manu" );
	
	RegisterHam( Ham_Spawn, "player", "OnPlayerSpawn_Post", true );
	RegisterHam( Ham_Killed, "player", "OnPlayerKilled_Pre", false );
	
	RegisterHookChain( RG_CBasePlayer_SetClientUserInfoModel, "OnSetClientUserInfoModel_Pre", false );
	
	DisableHamForward( ( g_hResetMaxSpeed = RegisterHam( Ham_CS_Player_ResetMaxSpeed, "player", "OnPlayerResetMaxSpeed_Pre", false ) ) );
	DisableHamForward( ( g_hWeaponTouch = RegisterHam( Ham_Touch, "weaponbox", "OnWeaponTouch_Pre", false ) ) );
	DisableHamForward( ( g_hArmouryTouch = RegisterHam( Ham_Touch, "armoury_entity", "OnWeaponTouch_Pre", false ) ) );
	DisableHamForward( ( g_hAddItem = RegisterHam( Ham_AddPlayerItem, "player", "OnAddPlayerItem_Pre", false ) ) );
	DisableHamForward( ( g_hImpulse = RegisterHam( Ham_Player_ImpulseCommands, "player", "OnPlayerImpulseCommand_Pre", false ) ) );
	DisableHamForward( ( g_hUseGameEquip = RegisterHam( Ham_Use, "game_player_equip", "OnGameEquipUse_Pre", false ) ) );
	DisableHamForward( ( g_hUseWeaponStrip = RegisterHam( Ham_Use, "player_weaponstrip", "OnWeaponStripUse_Pre", false ) ) );
	
	RegisterWeaponsDeploy( );
	
	register_message( get_user_msgid( "ScreenFade" ), "OnScreenFadeMessage" );
	
	register_clcmd( "drop", "ClientCommand_Drop" );
	register_clcmd( "fullupdate", "ClientCommand_FullUpdate" );
	register_clcmd( "nightvision", "ClientCommand_NightVision" );
	
	g_pCvarLightStyle = register_cvar( "mp_lightstyle", "m" );
}

/* =================================================================================
* 				[ Messages ]
* ================================================================================= */

public OnScreenFadeMessage( iMessage, iDest, iId )
{
	if ( !GetPlayerBit( g_iIsNightVisionOn, iId ) )
	{
		return PLUGIN_CONTINUE;
	}
	
	return PLUGIN_HANDLED;
}

/* =================================================================================
* 				[ Player Events ]
* ================================================================================= */

public OnPlayerSpawn_Post( iId )
{
	if ( !is_user_alive( iId ) )
	{
		return HAM_IGNORED;
	}
	
	SetPlayerBit( g_iIsAlive, iId );
	
	return HAM_IGNORED;
}

public OnPlayerKilled_Pre( iVictim, iAttacker, iShouldGib )
{
	ClearPlayerBit( g_iIsAlive, iVictim );
	
	__SetPlayerFrozen( iVictim, false, true );
	
	__SetPlayerBlock( iVictim, BLOCK_DROP, false );
	__SetPlayerBlock( iVictim, BLOCK_PICKUP, false );
	__SetPlayerBlock( iVictim, BLOCK_FLASHLIGHT, false );
	__SetPlayerBlock( iVictim, BLOCK_SHOOT, false );
	__SetPlayerBlock( iVictim, BLOCK_SPEED, false );
	__SetPlayerBlock( iVictim, BLOCK_ADD_ITEMS, false );
}

/* =================================================================================
* 				[ General Forwards ]
* ================================================================================= */

public OnAddPlayerItem_Pre( iId, iItem )
{
	if ( !GetPlayerBit( g_iHasBlock[ BLOCK_ADD_ITEMS ], iId ) || ( pev_valid( iItem ) != 2 ) )
	{
		return HAM_IGNORED;
	}
	
	set_entvar( iItem, var_flags, get_entvar( iItem, var_flags ) | FL_KILLME );
	set_entvar( iItem, var_nextthink, get_gametime( ) );
	
	return HAM_SUPERCEDE; 
}

public OnPlayerImpulseCommand_Pre( iId )
{
	if ( !GetPlayerBit( g_iHasBlock[ BLOCK_FLASHLIGHT ], iId ) || ( get_entvar( iId, var_impulse ) != 100 ) )
	{
		return HAM_IGNORED;
	}
	
	set_entvar( iId, var_impulse, 0 );
	
	return HAM_HANDLED;
}

public OnWeaponStripUse_Pre( iEnt, iCaller, iActivator, iUseType, Float:flValue )
{
	if ( !GetPlayerBit( g_iHasBlock[ BLOCK_ADD_ITEMS ], iCaller ) )
	{
		return HAM_IGNORED;
	}
	
	if ( ( flValue != 0.0 ) || ( iUseType != 3 ) )
	{
		return HAM_IGNORED;
	}
	
	return HAM_SUPERCEDE;
}

public OnWeaponTouch_Pre( const iEnt, const iOther )
{
	if ( !GetPlayerBit( g_iIsAlive, iOther ) || !GetPlayerBit( g_iHasBlock[ BLOCK_PICKUP ], iOther ) )
	{
		return HAM_IGNORED;
	}
	
	return HAM_SUPERCEDE;
}

public OnGameEquipUse_Pre( iEnt, iCaller, iActivator, iUseType, Float:flValue )
{
	if ( !GetPlayerBit( g_iHasBlock[ BLOCK_ADD_ITEMS ], iCaller ) )
	{
		return HAM_IGNORED;
	}
	
	if ( ( flValue != 0.0 ) || ( iUseType != 3 ) )
	{
		return HAM_IGNORED;
	}
	
	return HAM_SUPERCEDE;
}

public OnItemDeploy_Post( iEnt )
{
	new iOwner = get_member( iEnt, m_pPlayer );
	
	if ( !GetPlayerBit( g_iHasBlock[ BLOCK_SHOOT ], iOwner ) )
	{
		return HAM_IGNORED;
	}
	
	set_member( iOwner, m_flNextAttack, get_gametime( ) + 999.0 );
	
	return HAM_IGNORED;
}

public OnPlayerResetMaxSpeed_Pre( iId )
{
	if ( !GetPlayerBit( g_iIsAlive, iId ) || !GetPlayerBit( g_iHasBlock[ BLOCK_SPEED ], iId ) )
	{
		return HAM_IGNORED;
	}
	
	return HAM_SUPERCEDE;
}

public OnSetClientUserInfoModel_Pre( iId, szBuffer[ ], szModel[ ] )
{
	if ( !GetPlayerBit( g_iIsModelled, iId ) || equal( szModel, g_sPlayers[ iId ][ Player_Model ] ) )
	{
		return HC_CONTINUE;
	}
	
	SetHookChainArg( 3, ATYPE_STRING, g_sPlayers[ iId ][ Player_Model ] );

	return HC_CONTINUE;
}

/* =================================================================================
* 				[ Client Connection ]
* ================================================================================= */

public client_putinserver( iId )
{
	SetPlayerBit( g_iIsConnected, iId );
}

public client_disconnected( iId )
{
	ClearPlayerBit( g_iIsConnected, iId );
	ClearPlayerBit( g_iIsAlive, iId );
	ClearPlayerBit( g_iIsFrozen, iId );
	ClearPlayerBit( g_iIsModelled, iId );
	ClearPlayerBit( g_iIsNightVisionOn, iId );
	
	ClearPlayerBit( g_iHasNightVision, iId );
	
	__SetPlayerBlock( iId, BLOCK_DROP, false );
	__SetPlayerBlock( iId, BLOCK_PICKUP, false );
	__SetPlayerBlock( iId, BLOCK_FLASHLIGHT, false );
	__SetPlayerBlock( iId, BLOCK_SHOOT, false );
	__SetPlayerBlock( iId, BLOCK_SPEED, false );
	__SetPlayerBlock( iId, BLOCK_ADD_ITEMS, false );
}

/* =================================================================================
* 				[ Client Commands ]
* ================================================================================= */

public ClientCommand_Drop( iId )
{
	if ( GetPlayerBit( g_iHasBlock[ BLOCK_DROP ], iId ) )
	{
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public ClientCommand_NightVision( iId )
{
	if ( !GetPlayerBit( g_iHasNightVision, iId ) )
	{
		return PLUGIN_CONTINUE;
	}
	
	static szLightStyle[ 16 ];
	
	get_pcvar_string( g_pCvarLightStyle, szLightStyle, charsmax( szLightStyle ) );
	
	if ( GetPlayerBit( g_iIsNightVisionOn, iId ) )
	{
		ClientPlaySound( iId, g_szNightVisionOffSound );
		
		SendScreenFade( iId, { 0, 0, 0 }, 0, 0, 0, 0 );
		SendLightStyle( iId, 0, szLightStyle );
		
		ClearPlayerBit( g_iIsNightVisionOn, iId );
	}
	else
	{
		ClientPlaySound( iId, g_szNightVisionOnSound );
		
		SendLightStyle( iId, 0, "m" );
		SendScreenFade( iId, { 30, 255, 30 }, 0, 0, 0x0004, 50 );
		
		SetPlayerBit( g_iIsNightVisionOn, iId );
	}
	
	return PLUGIN_HANDLED;
}

public ClientCommand_FullUpdate( iId )
{
	return PLUGIN_HANDLED;
}

/* =================================================================================
* 				[ Modules ]
* ================================================================================= */

RegisterWeaponsDeploy( )
{
	new szWeapon[ 32 ];
	
	for ( new i = 0 ; i < MAX_WEAPONS ; i++ )
	{
		if ( CSW_NOT_WEAPON & ( 1 << i ) )
		{
			continue;
		}
		
		get_weaponname( i, szWeapon, charsmax( szWeapon ) );
		
		DisableHamForward( ( g_hDeploy[ i ] = RegisterHam( Ham_Item_Deploy, szWeapon, "OnItemDeploy_Post", true ) ) );
	}
}

EnableForwards( const iBlock )
{
	switch ( iBlock )
	{
		case BLOCK_SHOOT:
		{
			for ( new i = 0 ; i < MAX_WEAPONS ; i++ )
			{
				if ( CSW_NOT_WEAPON & ( 1 << i ) )
				{
					continue;
				}
				
				EnableHamForward( g_hDeploy[ i ] );
			}
		}
		case BLOCK_PICKUP:
		{
			EnableHamForward( g_hWeaponTouch );
			EnableHamForward( g_hArmouryTouch );
		}
		case BLOCK_FLASHLIGHT:
		{
			EnableHamForward( g_hImpulse );
		}
		case BLOCK_SPEED:
		{
			EnableHamForward( g_hResetMaxSpeed );
		}
		case BLOCK_ADD_ITEMS:
		{
			EnableHamForward( g_hAddItem );
			EnableHamForward( g_hUseGameEquip );
			EnableHamForward( g_hUseWeaponStrip );
		}
	}
}

DisableForwards( const iBlock )
{
	switch ( iBlock )
	{
		case BLOCK_SHOOT:
		{
			for ( new i = 0 ; i < MAX_WEAPONS ; i++ )
			{
				if ( CSW_NOT_WEAPON & ( 1 << i ) )
				{
					continue;
				}
				
				DisableHamForward( g_hDeploy[ i ] );
			}
		}
		case BLOCK_PICKUP:
		{
			DisableHamForward( g_hWeaponTouch );
			DisableHamForward( g_hArmouryTouch );
		}
		case BLOCK_FLASHLIGHT:
		{
			DisableHamForward( g_hImpulse );
		}
		case BLOCK_SPEED:
		{
			DisableHamForward( g_hResetMaxSpeed );
		}
		case BLOCK_ADD_ITEMS:
		{
			DisableHamForward( g_hAddItem );
			DisableHamForward( g_hUseGameEquip );
			DisableHamForward( g_hUseWeaponStrip );
		}
	}
}

__SetPlayerFrozen( iPlayer, iState, iEffects )
{
	if ( GetPlayerBit( g_iIsFrozen, iPlayer ) == ( iState > 0 ) )
	{
		return;
	}
	
	new iFlags = get_entvar( iPlayer, var_flags );
	
	if ( iState > 0 )
	{
		if ( iEffects > 0 )
		{
			set_entvar( iPlayer, var_renderfx, kRenderFxGlowShell );
			set_entvar( iPlayer, var_renderamt, 40.0 );
			set_entvar( iPlayer, var_rendercolor, Float:{ 0.0, 140.0, 240.0 } );
			
			rh_emit_sound2( iPlayer, 0, CHAN_AUTO, g_szFreezeSound );
		}
		
		set_entvar( iPlayer, var_velocity, Float:{ 0.0, 0.0, 0.0 } );
		set_entvar( iPlayer, var_flags, ( iFlags | FL_FROZEN ) );
		
		SetPlayerBit( g_iIsFrozen, iPlayer );
	}
	else
	{
		set_entvar( iPlayer, var_flags, ( iFlags & ~FL_FROZEN ) );
		
		if ( iEffects > 0 )
		{
			set_entvar( iPlayer, var_renderfx, kRenderFxNone );
			set_entvar( iPlayer, var_renderamt, 0.0 );
			set_entvar( iPlayer, var_rendercolor, Float:{ 0.0, 0.0, 0.0 } );
			
			rh_emit_sound2( iPlayer, 0, CHAN_AUTO, g_szUnfreezeSound );
		}
		
		ClearPlayerBit( g_iIsFrozen, iPlayer );
	}
}

__SetPlayerNightVision( iPlayer, iState )
{
	if ( GetPlayerBit( g_iHasNightVision, iPlayer ) == ( iState > 0 ) )
	{
		return;
	}
	
	if ( iState > 0 )
	{
		SetPlayerBit( g_iHasNightVision, iPlayer );
		
		if ( iState > 1 )
		{
			ClientCommand_NightVision( iPlayer );
		}
	}
	else
	{
		if ( GetPlayerBit( g_iIsNightVisionOn, iPlayer ) )
		{
			ClientCommand_NightVision( iPlayer );
		}
		
		ClearPlayerBit( g_iHasNightVision, iPlayer );
	}
}

__SetPlayerBlock( iPlayer, iBlock, iState )
{
	if ( GetPlayerBit( g_iHasBlock[ iBlock ], iPlayer ) == ( iState > 0 ) )
	{
		return;
	}
	
	if ( iState > 0 )
	{
		if ( !g_iHasBlock[ iBlock ] )
		{
			EnableForwards( iBlock );
		}
		
		SetPlayerBit( g_iHasBlock[ iBlock ], iPlayer );
	}
	else
	{
		ClearPlayerBit( g_iHasBlock[ iBlock ], iPlayer );
		
		if ( !g_iHasBlock[ iBlock ] )
		{
			DisableForwards( iBlock );
		}
	}
	
	if ( ( iBlock == BLOCK_SHOOT ) && GetPlayerBit( g_iIsAlive, iPlayer ) )
	{
		( iState > 0 ) ?
			set_member( iPlayer, m_flNextAttack, get_gametime( ) + 999.0 ) :
			set_member( iPlayer, m_flNextAttack, 0.0 );
	}
}

/* =================================================================================
* 				[ Natives ]
* ================================================================================= */

public _UTIL_SetPlayerModel( iPlugin, iParams )
{
	new iPlayer = get_param( 1 );
	
	if ( !GetPlayerBit( g_iIsConnected, iPlayer ) )
	{
		return;
	}
	
	SetPlayerBit( g_iIsModelled, iPlayer );
	
	get_string( 2, g_sPlayers[ iPlayer ][ Player_Model ], charsmax( g_sPlayers[ ][ Player_Model ] ) );
	
	rg_set_user_model( iPlayer, g_sPlayers[ iPlayer ][ Player_Model ], true );
}

public _UTIL_GetPlayerModel( iPlugin, iParams )
{
	new iPlayer = get_param( 1 );
	
	if ( !GetPlayerBit( g_iIsModelled, iPlayer ) )
	{
		return false;
	}
	
	new iSize = get_param( 3 );
	
	set_string( 2, g_sPlayers[ iPlayer ][ Player_Model ], iSize );
	
	return true;
}

public _UTIL_SetPlayerFrozen( iPlugin, iParams )
{
	new iPlayer = get_param( 1 );
	new iState = get_param( 2 );
	new iEffects = get_param( 3 );
	
	if ( !GetPlayerBit( g_iIsAlive, iPlayer ) )
	{
		return;
	}
	
	__SetPlayerFrozen( iPlayer, iState, iEffects );
}

public _UTIL_GetPlayerFrozen( iPlugin, iParams )
{
	new iPlayer = get_param( 1 );
	
	if ( GetPlayerBit( g_iIsFrozen, iPlayer ) )
	{
		return true;
	}
	
	return false;
}

public _UTIL_SetPlayerNVG( iPlugin, iParams )
{
	new iPlayer = get_param( 1 );
	new iState = get_param( 2 );
	
	if ( !GetPlayerBit( g_iIsConnected, iPlayer ) )
	{
		return;
	}
	
	__SetPlayerNightVision( iPlayer, iState );
}

public _UTIL_GetPlayerNVG( iPlugin, iParams )
{
	new iPlayer = get_param( 1 );
	
	if ( GetPlayerBit( g_iHasNightVision, iPlayer ) )
	{
		if ( GetPlayerBit( g_iIsNightVisionOn, iPlayer ) )
		{
			return 2;
		}
		
		return 1;
	}
	
	return 0;
}

public _UTIL_SetPlayerBlock( iPlugin, iParams )
{
	new iPlayer = get_param( 1 );
	new iBlock = get_param( 2 );
	new iState = get_param( 3 );
	
	if ( !GetPlayerBit( g_iIsAlive, iPlayer ) )
	{
		return;
	}
	
	__SetPlayerBlock( iPlayer, iBlock, iState );
}

public _UTIL_GetPlayerBlock( iPlugin, iParams )
{
	new iPlayer = get_param( 1 );
	new iBlock = get_param( 2 );
	
	if ( GetPlayerBit( g_iHasBlock[ iBlock ], iPlayer ) )
	{
		return true;
	}
	
	return false;
}