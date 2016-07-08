/* The HandleMngr module provides an interface for the workspace
  service to make handles sharable. When the owner shares a
  workspace object that contains Handles, the underlying shock
  object is made readable to the person that the workspace object
  is being shared with.
*/
module HandleMngr {
	/* The is_readable function will return true if the
	  underlying shock object is readable by the owner of the
	  token. The token is passed by the client.
	*/
	funcdef is_readable(string token, string nodeurl) returns(int) authentication
		optional;

	typedef string HandleId;

	/* The add_read_acl function will update the acl of the shock
	  node that the handle references. The function is only accessible to a 
	  specific list of users specified at startup time. The underlying
	  shock node will be made readable to the user requested.
	*/
	funcdef add_read_acl(list<HandleId> hids, string username)
		returns () authentication required;

	/* The set_public_read function will update the acl of the shock
	  node that the handle references to make the node globally readable.
	  The function is only accessible to a specific list of users specified
	  at startup time.
	*/
	funcdef set_public_read(list<HandleId> hids)
		returns () authentication required;
};
