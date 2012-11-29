//
//  main.m
//  Skype Launcher
//
//  Created by Alexander Holodny on 11/27/12.
//  Copyright (c) 2012 Alexander Holodny. All rights reserved.
//

AuthorizationRef _authorizationRef;

BOOL acquirePrivileges();
void releasePrivileges();

int main(int argc, const char * argv[])
{
	@autoreleasepool
	{
		NSArray *apps = [[NSWorkspace sharedWorkspace] runningApplications];
		NSString *skype = @"/Applications/Skype.app/Contents/MacOS/Skype";
		pid_t loginWindowPid = 0, skypePid = 0;
		
		if ([[NSFileManager defaultManager] fileExistsAtPath:skype] == NO)
		{
			[[NSAlert alertWithMessageText:@"Error"
							 defaultButton:@"Quit"
						   alternateButton:nil
							   otherButton:nil
				 informativeTextWithFormat:@"Skype app not found"]
			 runModal];
			
			return -1;
		}
		
		for (NSRunningApplication *app in apps)
		{
			if ([app.bundleIdentifier isEqualToString:@"com.apple.loginwindow"])
			{
				loginWindowPid = app.processIdentifier;
			}
			
			if ([app.bundleIdentifier isEqualToString:@"com.skype.skype"])
			{
				skypePid = app.processIdentifier;
			}
		}
		
		if ( 0 == skypePid )
		{
			[[NSWorkspace sharedWorkspace] launchApplicationAtURL:[NSURL fileURLWithPath:skype]
														  options:0
													configuration:NULL
															error:NULL];
		}
		else if ( 0 != loginWindowPid)
		{
			char pid[16] = {0};
			
			snprintf(pid, sizeof(pid), "%d", loginWindowPid);
			
			if (acquirePrivileges())
			{
				FILE *pipe = NULL;
				char * args[] = {
					"-u",
					"root",
					"/",
					"launchctl",
					"bsexec",
					NULL,
					(char*)skype.fileSystemRepresentation, NULL};
				
				args[5] = (char*)&pid;
				
				AuthorizationExecuteWithPrivileges(_authorizationRef, "/usr/sbin/chroot", kAuthorizationFlagDefaults, args, &pipe);
				
				releasePrivileges();
				return 0;
			}
		}
		else
		{
			[[NSAlert alertWithMessageText:@"Error"
							 defaultButton:@"Quit"
						   alternateButton:nil
							   otherButton:nil
				 informativeTextWithFormat:@"No loginwindow found"]
			 runModal];
		}
	}
	
    return -1;
}

BOOL acquirePrivileges()
{
	AuthorizationItem authItems = {kAuthorizationRightExecute, 0, NULL, 0};
	AuthorizationRights authRights = {1, &authItems};
	OSStatus status = 0;
	
	status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &_authorizationRef);
	
	if ( errAuthorizationSuccess != status )
	{
		NSLog(@"AuthorizationCreate failed with %d", (int)status);
		return NO;
	}
	
	status = AuthorizationCopyRights(_authorizationRef, &authRights, NULL,
									 kAuthorizationFlagDefaults | kAuthorizationFlagInteractionAllowed |
									 kAuthorizationFlagPreAuthorize | kAuthorizationFlagExtendRights, NULL);
	
	if ( errAuthorizationSuccess != status )
	{
		NSLog(@"AuthorizationCopyRights failed with %d", (int)status);
		releasePrivileges();
		return NO;
	}
	
	return YES;
}

void releasePrivileges()
{
	if (_authorizationRef)
	{
		OSStatus status = AuthorizationFree(_authorizationRef, kAuthorizationFlagDestroyRights);
		
		if ( errAuthorizationSuccess != status)
			NSLog(@"AuthorizationFree failed with %d", (int)status);
		
		_authorizationRef = NULL;
	}
}
