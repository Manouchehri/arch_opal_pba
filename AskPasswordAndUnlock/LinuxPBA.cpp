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

using namespace std;
#include <unistd.h>
#include <sys/reboot.h>
#include "log.h"
#include "UnlockSEDs.h"
#include <vector>
#include <unistd.h>

int main(int argc, char** argv)
{
	char* pw = getpass("Please enter pass-phrase to unlock OPAL drives: ");
	if (pw)
	{
		if (UnlockSEDs(pw) == 0)
		{
			sleep(6);
			sync();
			return EXIT_SUCCESS;
		}
	}
	return EXIT_FAILURE;
}

