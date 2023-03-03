#property copyright "Xefino"
#property version   "1.10"
#property strict

// Winsock constants
#define SOCKET_HANDLE32       uint
#define SOCKET_HANDLE64       ulong
#define AF_INET               2
#define SOCK_STREAM           1
#define IPPROTO_TCP           6
#define INVALID_SOCKET32      0xFFFFFFFF
#define INVALID_SOCKET64      0xFFFFFFFFFFFFFFFF
#define SOCKET_ERROR          -1
#define INADDR_NONE           0xFFFFFFFF
#define FIONBIO               0x8004667E
#define WSAWOULDBLOCK         10035

struct sockaddr {
   short family;
   ushort port;
   uint address;
   ulong ignore;
};

struct linger {
   ushort onoff;
   ushort linger_seconds;
};

// DLL imports
#import "ws2_32.dll"

   // Imports for 32-bit environment
   SOCKET_HANDLE32 socket(int, int, int); // Artificially differs from 64-bit version based on 3rd parameter
   int connect(SOCKET_HANDLE32, sockaddr&, int);
   int closesocket(SOCKET_HANDLE32);
   int send(SOCKET_HANDLE32, uchar&[], int, int);
   int recv(SOCKET_HANDLE32, uchar&[], int, int);
   int ioctlsocket(SOCKET_HANDLE32, uint, uint&);
   int bind(SOCKET_HANDLE32, sockaddr&, int);
   int listen(SOCKET_HANDLE32, int);
   SOCKET_HANDLE32 accept(SOCKET_HANDLE32, int, int);
   int WSAAsyncSelect(SOCKET_HANDLE32, int, uint, int);
   int shutdown(SOCKET_HANDLE32, int);
   
   // Imports for 64-bit environment
   SOCKET_HANDLE64 socket(int, int, uint); // Artificially differs from 32-bit version based on 3rd parameter
   int connect(SOCKET_HANDLE64, sockaddr&, int);
   int closesocket(SOCKET_HANDLE64);
   int send(SOCKET_HANDLE64, uchar&[], int, int);
   int recv(SOCKET_HANDLE64, uchar&[], int, int);
   int ioctlsocket(SOCKET_HANDLE64, uint, uint&);
   int bind(SOCKET_HANDLE64, sockaddr&, int);
   int listen(SOCKET_HANDLE64, int);
   SOCKET_HANDLE64 accept(SOCKET_HANDLE64, int, int);
   int WSAAsyncSelect(SOCKET_HANDLE64, long, uint, int);
   int shutdown(SOCKET_HANDLE64, int);

   // gethostbyname() has to vary between 32/64-bit, because it returns a memory pointer whose size will 
   // be either 4 bytes or 8 bytes. In order to keep the compiler happy, we therefore need versions which
   // take artificially-different parameters on 32/64-bit
   uint gethostbyname(uchar&[]); // For 32-bit
   ulong gethostbyname(char&[]); // For 64-bit

   // Neutral; no difference between 32-bit and 64-bit
   uint inet_addr(uchar&[]);
   int WSAGetLastError();
   uint htonl(uint);
   ushort htons(ushort);
#import

// For navigating the Winsock hostent structure, with indescribably horrible
// variation between 32-bit and 64-bit
#import "kernel32.dll"
   void RtlMoveMemory(uint&, uint, int);
   void RtlMoveMemory(ushort&, uint, int);
   void RtlMoveMemory(ulong&, ulong, int);
   void RtlMoveMemory(ushort&, ulong, int);
#import
