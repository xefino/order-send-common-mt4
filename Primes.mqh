#property copyright "Xefino"
#property version   "1.07"

// PrimeGenerator
// Copied over from MQL5, allows for generation of prime numbers
class PrimeGenerator {
private:
   const static int  s_primes[];       // table of prime numbers
   const static int  s_hash_prime;

public:

   // IsPrime returns whether or not a number is prime, true if it is, false otherwise
   //    candidate:  The number to be checked
   static bool IsPrime(const int candidate);
   
   // GetPrime returns the next prime greater than the minimum value provided
   //    min:        The minimum value for the desired prime
   static int GetPrime(const int min);
   
   // ExpandPrime returns a prime at least twice as large as the value provided
   //    old:        The old prime value to be expanded
   static int ExpandPrime(const int old);
};

const static int PrimeGenerator::s_primes[] = {
   3,7,11,17,23,29,37,47,59,71,89,107,131,163,197,239,293,353,431,521,631,761,919,
   1103,1327,1597,1931,2333,2801,3371,4049,4861,5839,7013,8419,10103,12143,14591,
   17519,21023,25229,30293,36353,43627,52361,62851,75431,90523,108631,130363,156437,
   187751,225307,270371,324449,389357,467237,560689,672827,807403,968897,1162687,1395263,
   1674319,2009191,2411033,2893249,3471899,4166287,4999559,5999471,7199369,8332579,
   9999161,11998949,14398753,16665163,19998337,23997907,28797523,33330329,39996683,
   47995853,57595063,66660701,79993367,95991737,115190149,133321403,159986773,191983481,
   230380307,266642809,319973567,383966977,460760623,533285671,639947149,767933981,
   921521257,1066571383,1279894313,1535867969,1843042529,2133142771
};

const static int PrimeGenerator::s_hash_prime = 101;

// IsPrime returns whether or not a number is prime, true if it is, false otherwise
//    candidate:  The number to be checked
bool PrimeGenerator::IsPrime(const int candidate) {
   
   // Check if the value is odd; if it is then we'll try the Seive of Eratosthenes
   if ((candidate & 1) != 0) {
      int limit = (int)MathSqrt(candidate);
      for (int divisor = 3; divisor <= limit; divisor += 2) {
         if ((candidate % divisor) == 0) {
            return false;
         }
      }
      
      return true;
   }
   
   // If we got to this point then the number is even. The only even prime
   // is two so return the value of that check
   return candidate == 2;
}

// GetPrime returns the next prime greater than the minimum value provided
//    min:        The minimum value for the desired prime
int PrimeGenerator::GetPrime(const int min) {

   // First, iterate over the list of primes and check whether or not we can
   // use one of those values; if we can then return it
   for (int i = 0; i < ArraySize(s_primes); i++) {
      int prime = s_primes[i];
      if (prime >= min) {
         return prime;
      }
   }
   
   // Next, since we didn't find the value in our pre-computed list, we'll iterate
   // over possible prime candidates and check whether or not each is prime until
   // we find one; return it if we find it
   for (int i = (min|1); i <= INT_MAX; i += 2) {
      if(IsPrime(i) && ((i - 1) % s_hash_prime != 0)) {
         return i;
      }
   }
   
   // Finally, return the original value if we couldn't find a prime
   return min;
}

// ExpandPrime returns a prime at least twice as large as the value provided
//    old:        The old prime value to be expanded
int PrimeGenerator::ExpandPrime(const int old) {
   if (old >= INT_MAX / 2) {
      return INT_MAX;
   }
   
   return GetPrime(old * 2);
}