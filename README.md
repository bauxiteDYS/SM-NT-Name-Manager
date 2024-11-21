# SM-NT-Force-Name.
Sourcemod Plugin for Neotokyo that forced a specific name on a client, branch of the name manager which has additional features. A client can't be force named to `0` or `off` as that's how the plugin checks if the forced name should be disabled on a client, otherwise it's enabled and their name is set to whatever string the plugin recieves in the `sm_forcename` command.

`sm_forcename` : Force a name on a client.   
Usage: `sm_forcename <target_client> <new_name>` to force a new name on a client.  
Usage: `sm_forcename <target_client> <off | 0>` to disable the forced name.
