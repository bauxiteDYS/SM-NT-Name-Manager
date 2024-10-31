# SM-NT-Name-Manager - Sort of experimental.
Sourcemod Plugin for Neotokyo that stores a default name for every client, disallows clients from changing that name to prevent fake-nicks or for tournaments etc. Supports automatically forcing all clients or only specific ones using the `sm_forcename` command.

`sm_storename` : Override a stored name for a client, the plugin will store the first name a client joins with as the default name.   
Usage: `sm_storename <target_client> <new_name>`  

`sm_forcename` : Turn on/off the forced name on a client.   
Usage: `sm_forcename <target_client> <on | off>`  

`sm_shownames` : Print into console the names of all clients followed by their stored name, to easily look up the real identity of fakenick players without having to look up steamid probably, mostly useful if the `sm_name_force` cvar is not set to `2`.  

`sm_name_force` : Server CVAR to enable forced usage of stored name, either `0` to disable, or `1` to enable for specific clients only, or `2` to enable for all clients.
