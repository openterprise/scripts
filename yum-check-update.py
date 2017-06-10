#!/usr/bin/env python

from tkinter import *
from tkinter import messagebox

import time
import threading
import os
import subprocess




pid = os.getpid()

result = os.system("yum check-update > /tmp/yum-check-update."+str(pid))



print ( "Exit code: "+str(result))

if result == 0:
    print ( "No updates")
else:
    print ( "Updates found")
    
    
    with open("/tmp/yum-check-update."+str(pid), "r") as ins:
        array = []
        for line in ins:
            if ".i686" in line:
                array.append(line.strip())
            elif ".i386" in line:
                array.append(line.strip())
            elif ".x86_64" in line:
                array.append(line.strip())
            elif ".noarch" in line:
                array.append(line.strip())
            elif ".src" in line:
                array.append(line.strip())
                
    print(str(len(array)))
    
    result = messagebox.askyesno("System updates found",str(len(array))+" updates found. Perform system update?")
    print(result);
    
    if result == True:
        print ("Performing system update")
        os.system('sudo yum update -y')
        messagebox.showinfo("System update finished", "System update finished")     
    else:
        print ("Update canceled")





#prints current kernel version
subout = (subprocess.Popen(['uname','-r'], bufsize=1024, stdout=subprocess.PIPE)).stdout
for line in subout:
    currentkernel = line.strip()
    print ( currentkernel.decode("utf-8") )


#prints last kernel version
subout = (subprocess.Popen(['rpm', '-q', 'kernel'], bufsize=1024, stdout=subprocess.PIPE)).stdout
#go for every kernel found
#last one is at the end
for line in subout:
    kernel = line.strip()
    #print ( kernel )
    global lastkernel
    lastkernel = kernel


#prints last kernel
lastkernel = lastkernel.replace (b'kernel-', b'')
print( lastkernel.decode("utf-8") )


if lastkernel == currentkernel:
    print ("Kernel up to date")
else:
    print ("Reboot needed for loading new kernel")
    
    
    result = messagebox.askyesno("New kernel found","New kernel found: "+ lastkernel.decode("utf-8") +". Perform system restart?")
    print(result);
    
    if result == True:
        print ("Performing system reboot")
        os.system('reboot')
        messagebox.showinfo("Restarting..", "System restarting...")      
    else:
        print ("Reboot canceled")
    
    
