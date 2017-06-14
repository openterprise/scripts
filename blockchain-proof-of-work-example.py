
import hashlib
import time

#selecting hashing algorithm
hash256 = hashlib.sha256()


#searching for hash starting with '00' in hex
time_current = time.time()
nonce=0
while True:
   hash256.update(str(nonce).encode())
   hashed_bytes = hash256.digest()
   
   if (hashed_bytes[0] == 0):
        time_end = time.time()
        time_diff = time_end - time_current
        print ('Nonce: '+str(nonce))
        print ('Hash(Nonce): '+hash256.hexdigest())
        print ('Seconds: '+str(time_diff))
        print ()
        break
    
   nonce+=1



#searching for hash starting with '0000' in hex
time_current = time.time()
nonce=0
while True:
   hash256.update(str(nonce).encode())
   hashed_bytes = hash256.digest()
   
   if (hashed_bytes[0] == 0) & (hashed_bytes[1] == 0):
        time_end = time.time()
        time_diff = time_end - time_current
        print ('Nonce: '+str(nonce))
        print ('Hash(Nonce): '+hash256.hexdigest())
        print ('Seconds: '+str(time_diff))
        print ()
        break
    
   nonce+=1


#searching for hash starting with '000000' in hex
time_current = time.time()
nonce=0
while True:
   hash256.update(str(nonce).encode())
   hashed_bytes = hash256.digest()
   
   if (hashed_bytes[0] == 0) & (hashed_bytes[1] == 0) & (hashed_bytes[2] == 0):
        time_end = time.time()
        time_diff = time_end - time_current
        print ('Nonce: '+str(nonce))
        print ('Hash(Nonce): '+hash256.hexdigest())
        print ('Seconds: '+str(time_diff))
        print ()
        break
    
   nonce+=1


#searching for hash starting with '00000000' in hex
time_current = time.time()
nonce=0
while True:
   hash256.update(str(nonce).encode())
   hashed_bytes = hash256.digest()
   
   if (hashed_bytes[0] == 0) & (hashed_bytes[1] == 0) & (hashed_bytes[2] == 0) & (hashed_bytes[3] == 0):
        time_end = time.time()
        time_diff = time_end - time_current
        print ('Nonce: '+str(nonce))
        print ('Hash(Nonce): '+hash256.hexdigest())
        print ('Seconds: '+str(time_diff))
        print ()
        break
    
   nonce+=1

