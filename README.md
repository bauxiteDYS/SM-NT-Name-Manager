# SM-NT-Name-Manager
Sourcemod Plugin for Neotokyo that stores a default name for every client, can automatically change to that name to prevent fake-nicks  

`!forcename` : Store a default name for a client, it will default to the first name they ever use on the server after installing the plugin, you can override this with the command to anything you want. Usage: `!forcename <fakenickplayer> <nameyouwant>`  

`!shownames` : Print into console the names of all players followed by their stored name, to easily look up the real identity of fakenick players without having to look up steamid probably, mostly useful if the `sm_name_force` cvar is set to `0`.  

`sm_name_force` : Server CVAR to enable automatic name change to force default stored names, either `0` to disable, or `1` to enable. Set it in the `server.cfg` if you want.
