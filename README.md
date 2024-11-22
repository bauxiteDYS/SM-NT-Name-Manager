# SM-NT-Name-Manager - Sort of experimental.
Sourcemod Plugin for Neotokyo that stores a default name for every client, disallows clients from changing that name to prevent fake-nicks or for tournaments etc. Supports automatically forcing all clients or only specific ones using the `sm_forcename` command. Clients can't be force named to `1` or `on` as they are reserved for the plugin functions.

**Commands:**  

- `sm_storename <target_client> <new_name>` : Set a new stored name for a client, the plugin will store the first name a client joins with as the default name. It will force players to this name depending on the setting of `sm_name_force` CVAR.   

- `sm_forcename <target_client> <on | off>` : Enable the forcing of the stored name on a specific client
- `sm_forcename <target_client> <new_name>` : Enable forcing and set a new stored name on a specific client. 

`sm_shownames` : Print into console the names of all clients followed by their stored name, to easily look up the real identity of fakenick players without having to look up steamid probably, mostly useful if the `sm_name_force` cvar is not set to `2`.  

**CVARS:**  

`sm_name_force` : Server CVAR to enable forced usage of stored name, either `0` to disable, or `1` to enable for specific clients only, or `2` to enable for all clients.
