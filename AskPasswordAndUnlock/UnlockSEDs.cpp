/* C:B**************************************************************************
 This software is Copyright 2014-2016 Bright Plaza Inc. <drivetrust@drivetrust.com>

 This file is part of sedutil.

 sedutil is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 sedutil is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with sedutil.  If not, see <http://www.gnu.org/licenses/>.

 * C:E********************************************************************** */

#include "UnlockSEDs.h"
#include "DtaDevGeneric.h"
#include "DtaDevOpal1.h"
#include "DtaDevOpal2.h"
#include <unistd.h>
#include <dirent.h>
#include <stdio.h>

static int UnlockDevice(DtaDev& d, const char* devref, char* password)
{
	d.no_hash_passwords = false;

	printf("Unlocking %s\n", devref);
	int result = -1;
	if (d.MBREnabled())
	{
		if (d.setMBRDone(1, password) == 0)
		{
			if (d.setLockingRange(0, OPAL_LOCKINGSTATE::READWRITE, password) == 0)
			{
				result = 0;
			}
			else
			{
				LOG(E) << "Unlock failed - unable to set LockingRange 0 RW";
			}
		}
		else
		{
			LOG(E) << "Unlock failed - unable to set MBRDone";
		}
	}
	else
	{
		LOG(I) << "MBR not enabled";
		result = 0;
	}

	return result;
}

uint8_t UnlockSEDs(char * password)
{
	int result = -1;

	DIR* d;
	struct dirent* dir;
	d = opendir("/sys/block/");
	if (d)
	{
		LOG(D4) << "Enter UnlockSEDs";
		printf("Scanning...\n");

		while ((dir = readdir(d)) != NULL)
		{
			char devref[16];
			//if (dir->d_name[0] != '.')
			if (dir->d_name[0] && dir->d_name[0] == 's' && dir->d_name[1] && dir->d_name[1] == 'd')
			{
				snprintf(devref, sizeof(devref), "/dev/%s", dir->d_name);
				DtaDevGeneric tempDev(devref);
				if (tempDev.isPresent())
				{
					if (tempDev.isOpal2())
					{
						DtaDevOpal2 d(devref);
						result = UnlockDevice(d, devref, password);
					}
					else if (tempDev.isOpal1())
					{
						DtaDevOpal1 d(devref);
						result =  UnlockDevice(d, devref, password);
					}
					else
					{
						printf("Drive %s not supported\n", devref);
					}
				}
			}
		}
	}

	closedir(d);
	return result;
}


