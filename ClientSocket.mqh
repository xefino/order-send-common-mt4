#property copyright "Xefino"
#property version   "1.06"
#property strict

#include "SocketCommon.mqh"

// ClientSocket
// Object to allow client socket connections
class ClientSocket {
private:

   // Need different socket handles for 32-bit and 64-bit environments
   SOCKET_HANDLE32   m_socket32;
   SOCKET_HANDLE64   m_socket64;
   bool              m_connected;            // Whether or not the socket is connected
   int               m_last_WSA_error;       // The last WSA error we received
   string            m_pending_receive_data; // Backlog of incoming data, if using a message-terminator in Receive()
   bool              m_done_event_handling;  // Whether we're still handling events
   
   // Helper function that actually connects to a socket at a given address and port
   //    address:    The address to connect to as an integer
   //    port:       The port number to use for the connection
   void Connect(const uint address, const ushort port);
   
   // Helper function that creates a new socket
   void CreateSocket();
   
   // Helper function that sets up event-handling on a socket
   void SetupSocketEventHandling();
   
   // Helper function that attempts to send data on a character buffer with a given length on the socket
   //    data:    The data to be sent
   //    length:  The length of data to be send on the socket
   bool SendInner(uchar &data[], int length);
   
   // Helper function that receives data into a buffer from the socket
   //    results:    The data that will hold the data we received
   int ReceiveInner(uchar &results[]);
   
public:

   // Buffer sizes, overwriteable once the class has been created
   int ReceiveBufferSize;
   int SendBufferSize;

   // Creates a new socket client to connect locally on the port number provided
   //    port:  The port number to send and receive on
   ClientSocket(const ushort port);
   
   // Creates a new socket client to connect to a remote server located at the address and port provided
   //    host: The IP address or host name to connect to
   //    port: The port number to send and receive on
   ClientSocket(const string host, const ushort port);

   // Constructor used by ServerSocket() when accepting a client connection on a 32-bit socket
   //    clientSock: The socket being used for the connection
   ClientSocket(const SOCKET_HANDLE32 clientSock);
   
   // Constructor used by ServerSocket() when accepting a client connection on a 64-bit socket
   //    clientSock: The socket being used for the connection
   ClientSocket(const SOCKET_HANDLE64 clientSock);

   // Destructor that releases resources associated with this instance of the client socket
   ~ClientSocket();
   
   // Send sends a string message to the connected server, returning true if the data was sent without error
   // or false if an error occurred
   //    message:    The message to be sent
   bool Send(const string message);
   
   // Simple send function which takes an array of uchar[], instead of a string. Can optionally be given a start-index
   // within the array (rather then default zero) and a number of bytes to send.
   //    data:       The buffer containing the data to be sent
   //    start:      The starting index of the data to be sent
   //    numChars:   The number of bytes to send
   bool Send(const uchar &data[], const int start = 0, const int numChars = -1);
   
   // Simple receive function. Without a message separator, it simply returns all the data sitting on the socket.
   // With a separator, it stores up incoming data until it sees the separator, and then returns the text minus
   // the separator. Returns a blank string once no more data is waiting for collection.
   //    sep:  The separator to split received data by
   string Receive(const string sep = "");
   
   // Receive function which fills an array, provided by reference. Always clears the array. Returns the number of
   // bytes put into the array. If you send and receive binary data, then you can no longer use the built-in messaging
   // protocol provided by this library's option to process a message terminator such as \r\n. You have to implement
   // the messaging yourself.
   //    buffer:     The data buffer to hold whatever we receive on the socket
   int Receive(uchar &buffer[]);
   
   // IsConnected returns whether or not the socket is connected
   bool IsConnected() const { return m_connected; }
   
   // LastError returns the last error code recorded on the socket connection
   int LastError() const { return m_last_WSA_error; }
   
   // Handle returns the socket handle associated with this connection
   ulong Handle() const { return (m_socket32 ? m_socket32 : m_socket64); }
};

// Creates a new socket client to connect locally on the port number provided
//    port: The port number to send and receive on
ClientSocket::ClientSocket(const ushort port) {
   CreateSocket();
   Connect(0x100007f, port);
}

// Creates a new socket client to connect to a remote server located at the address and port provided
//    host: The IP address or host name to connect to
//    port: The port number to send and receive on
ClientSocket::ClientSocket(const string host, const ushort port) {

   // First, attempt to create a socket we'll use for connections
   CreateSocket();
   #ifdef SOCKET_LIBRARY_LOGGING
      Print("Socket logging enabled");
   #endif

   // Next, check if the host is an IP address
   uchar arrName[];
   StringToCharArray(host, arrName);
   ArrayResize(arrName, ArraySize(arrName) + 1);
   uint addr = inet_addr(arrName);
   
   // Now, if we have an address that is a URL we need to convert that to an IP address
   if (addr == INADDR_NONE) {
   
      // Not an IP address. Need to look up the name
      // .......................................................................................
      // Unbelievably horrible handling of the hostent structure depending on whether
      // we're in 32-bit or 64-bit, with different-length memory pointers. 
      // Ultimately, we're having to deal here with extracting a uint** from
      // the memory block provided by Winsock - and with additional 
      // complications such as needing different versions of gethostbyname(),
      // because the return value is a pointer, which is 4 bytes in x86 and
      // 8 bytes in x64. So, we must artifically pass different types of buffer
      // to gethostbyname() depending on the environment, so that the compiler
      // doesn't treat them as imports which differ only by their return type.
      if (TerminalInfoInteger(TERMINAL_X64)) {
         char arrName64[];
         ArrayResize(arrName64, ArraySize(arrName));
         for (int i = 0; i < ArraySize(arrName); i++) {
            arrName64[i] = (char)arrName[i];
         }
         
         ulong nres = gethostbyname(arrName64);
         if (nres == 0) {
            m_last_WSA_error = WSAGetLastError();
            #ifdef SOCKET_LIBRARY_LOGGING
               Print("Name-resolution in gethostbyname() failed, 64-bit, error: ", m_last_WSA_error);
            #endif
            return;
         } else {
         
            // Need to navigate the hostent structure. Very, very ugly...
            ushort addrlen;
            RtlMoveMemory(addrlen, nres + 18, 2);
            if (addrlen == 0) {
               #ifdef SOCKET_LIBRARY_LOGGING
                  Print("Name-resolution in gethostbyname() returned no addresses, 64-bit, error: ", m_last_WSA_error);
               #endif
               return;
            } else {
               ulong ptr1, ptr2, ptr3;
               RtlMoveMemory(ptr1, nres + 24, 8);
               RtlMoveMemory(ptr2, ptr1, 8);
               RtlMoveMemory(ptr3, ptr2, 4);
               addr = (uint)ptr3;
            }
         }
      } else {
         uint nres = gethostbyname(arrName);
         if (nres == 0) {
            m_last_WSA_error = WSAGetLastError();
            #ifdef SOCKET_LIBRARY_LOGGING
               Print("Name-resolution in gethostbyname() failed, 32-bit, error: ", m_last_WSA_error);
            #endif
            return;
         } else {
         
            // Need to navigate the hostent structure. Very, very ugly...
            ushort addrlen;
            RtlMoveMemory(addrlen, nres + 10, 2);
            if (addrlen == 0) {
            
               // No addresses associated with name
               #ifdef SOCKET_LIBRARY_LOGGING
                  Print("Name-resolution in gethostbyname() returned no addresses, 32-bit, error: ", m_last_WSA_error);
               #endif
               return;
            } else {
               int ptr1, ptr2;
               RtlMoveMemory(ptr1, nres + 12, 4);
               RtlMoveMemory(ptr2, ptr1, 4);
               RtlMoveMemory(addr, ptr2, 4);
            }
         }
      }
   }
   
   // Finally, attempt to connect to the remote server on the port provided
   Connect(addr, port);
}

// Constructor used by ServerSocket() when accepting a client connection on a 32-bit socket
//    clientSock: The socket being used for the connection
ClientSocket::ClientSocket(const SOCKET_HANDLE32 clientSock) {
   m_connected = true;
   m_socket32 = clientSock;
   ReceiveBufferSize = 10000;
   SendBufferSize = 999999999;
}

// Constructor used by ServerSocket() when accepting a client connection on a 64-bit socket
//    clientSock: The socket being used for the connection
ClientSocket::ClientSocket(const SOCKET_HANDLE64 clientSock) {
   m_connected = true;
   m_socket64 = clientSock;
   ReceiveBufferSize = 10000;
   SendBufferSize = 999999999;
}

// Destructor that releases resources associated with this instance of the client socket
ClientSocket::~ClientSocket() {
   if (TerminalInfoInteger(TERMINAL_X64)) {
      if (m_socket64 != 0) {
         shutdown(m_socket64, 2);
         closesocket(m_socket64);
      }
   } else {
      if (m_socket32 != 0) {
         shutdown(m_socket32, 2);
         closesocket(m_socket32);
      }
   }   
}

// Send sends a string message to the connected server, returning true if the data was sent without error
// or false if an error occurred
//    message:    The message to be sent
bool ClientSocket::Send(const string message) {
   
   // First, if the socket isn't connected then return false
   if (!m_connected) {
      return false;
   }
   
   // Make sure that event handling is set up, if requested
   #ifdef SOCKET_LIBRARY_USE_EVENTS
      SetupSocketEventHandling();
   #endif 

   // Next, get the length of the message; ignore it if it's empty
   int sendLength = StringLen(message);
   if (sendLength == 0) {
      return true;
   }
  
   // Now, convert the message to an array of characters so we can send it
   bool retVal = true;
   uchar arr[];
   StringToCharArray(message, arr);
   
   // Finally, send the data on the socket; return the result of the operation
   return SendInner(arr, sendLength);
}


// Simple send function which takes an array of uchar[], instead of a string. Can optionally be given a start-index
// within the array (rather then default zero) and a number of bytes to send.
//    data:       The buffer containing the data to be sent
//    start:      The starting index of the data to be sent
//    numChars:   The number of bytes to send
bool ClientSocket::Send(const uchar &data[], const int start = 0, const int numChars = -1) {

   // First, if the socket isn't connected then return false
   if (!m_connected) {
      return false;
   }
   
   // Make sure that event handling is set up, if requested
   #ifdef SOCKET_LIBRARY_USE_EVENTS
      SetupSocketEventHandling();
   #endif 

   // Next, verify the array size. If we received an empty data or our start data is
   // greater than the length of the array then return
   int arraySize = ArraySize(data);
   if (!arraySize || start >= arraySize) {
      return true;
   }
   
   // Set the number of characters we want to send; if the length is zero or less
   // than zero then we want to send all the data
   int length = numChars;
   if (length <= 0) {
      length = arraySize;
   }
   
   // If we have a starting offset then we'll set the length to the remainder of the array
   if (start + length > arraySize) {
      length = arraySize - start;
   }
   
   // Now, take a copy of the array 
   uchar arr[];
   ArrayResize(arr, length);
   ArrayCopy(arr, data, 0, start, length);   
   
   // Finally, send the data on the socket; return the result of the operation
   return SendInner(arr, length);
}

// Simple receive function. Without a message separator, it simply returns all the data sitting on the socket.
// With a separator, it stores up incoming data until it sees the separator, and then returns the text minus
// the separator. Returns a blank string once no more data is waiting for collection.
//    sep:  The separator to split received data by
string ClientSocket::Receive(const string sep = "") {

   // First, check if the socket is connected. If it's not then return here
   if (!m_connected) {
      return "";
   }

   // Make sure that event handling is set up, if requested
   #ifdef SOCKET_LIBRARY_USE_EVENTS
      SetupSocketEventHandling();
   #endif
   
   // Next, receive all the data we can from the buffer
   string retVal = "";
   uchar buffer[];
   int res = ReceiveInner(buffer);
   if (res < 0) {
      return retVal;
   }
   
   // Now, copy all the data in the buffer to our pending received data and then copy the data
   // from the pending receive data to our return value if any exists
   StringAdd(m_pending_receive_data, CharArrayToString(buffer, 0, res));
   if (m_pending_receive_data != "") {
      if (sep == "") {
         retVal = m_pending_receive_data;
         m_pending_receive_data = "";
      } else {
         int idx = StringFind(m_pending_receive_data, sep);
         if (idx >= 0) {
         
            // Remove any leading strings that are equal to our separator
            while (idx == 0) {
               m_pending_receive_data = StringSubstr(m_pending_receive_data, idx + StringLen(sep));
               idx = StringFind(m_pending_receive_data, sep);
            }
            
            // Get the substring starting at the beginning until the next instance of the separator
            // Save the string data remaining after the separator
            retVal = StringSubstr(m_pending_receive_data, 0, idx);
            m_pending_receive_data = StringSubstr(m_pending_receive_data, idx + StringLen(sep));
         }
      }
   }
   
   // Finally, return all the data we retrieved
   return retVal;
}

// Receive function which fills an array, provided by reference. Always clears the array. Returns the number of
// bytes put into the array. If you send and receive binary data, then you can no longer use the built-in messaging
// protocol provided by this library's option to process a message terminator such as \r\n. You have to implement
// the messaging yourself.
//    buffer:     The data buffer to hold whatever we receive on the socket
int ClientSocket::Receive(uchar &buffer[]) {

   // First, check if the socket is connected. If it's not then return here
   if (!m_connected) {
      return 0;
   }
   
   // Next, resize the buffer to zero to ensure that no data is written that shouldn't be
   ArrayResize(buffer, 0);
   
   // Now sure that event handling is set up, if requested
   #ifdef SOCKET_LIBRARY_USE_EVENTS
      SetupSocketEventHandling();
   #endif
   
   // Finally, attempt to receive data on the buffer
   return ReceiveInner(buffer);
}

// Helper function that actually connects to a socket at a given address and port
//    address:    The address to connect to as an integer
//    port:       The port number to use for the connection
void ClientSocket::Connect(const uint address, const ushort port) {

   // First, create a fixed definition for connecting the server
   sockaddr server;
   server.family = AF_INET;
   server.port = htons(port);
   server.address = address;
   
   // Next, call connect and collect the result; the call has to differ between 32-bit and 64-bit
   int res;
   if (TerminalInfoInteger(TERMINAL_X64)) {
      res = connect(m_socket64, server, sizeof(sockaddr));
   } else {
      res = connect(m_socket32, server, sizeof(sockaddr));
   }
   
   // Finally, if the response was a socket error then we'll set the error and log it; otherwise we'll
   // set the connected value to true
   if (res == SOCKET_ERROR) {
      m_last_WSA_error = WSAGetLastError();
      #ifdef SOCKET_LIBRARY_LOGGING
         Print("connect() to localhost failed, error: ", m_last_WSA_error);
      #endif
      return;
   } else {
      m_connected = true;   
      
      // Set up event handling. Can fail if called in OnInit() when
      // MT4/5 is still loading, because no window handle is available
      #ifdef SOCKET_LIBRARY_USE_EVENTS
         SetupSocketEventHandling();
      #endif
   }
}

// Helper function that creates a new socket
void ClientSocket::CreateSocket() {

   // Set the default buffer sizes
   ReceiveBufferSize = 10000;
   SendBufferSize = 999999999;

   // Attempt to create either a 32-bit or 64-bit socket handle
   m_connected = false;
   m_last_WSA_error = 0;
   if (TerminalInfoInteger(TERMINAL_X64)) {
      uint proto = IPPROTO_TCP;
      m_socket64 = socket(AF_INET, SOCK_STREAM, proto);
      if (m_socket64 == INVALID_SOCKET64) {
         m_last_WSA_error = WSAGetLastError();
         #ifdef SOCKET_LIBRARY_LOGGING
            Print("socket() failed, 64-bit, error: ", m_last_WSA_error);
         #endif
         return;
      }
   } else {
      int proto = IPPROTO_TCP;
      m_socket32 = socket(AF_INET, SOCK_STREAM, proto);
      if (m_socket32 == INVALID_SOCKET32) {
         m_last_WSA_error = WSAGetLastError();
         #ifdef SOCKET_LIBRARY_LOGGING
            Print("socket() failed, 32-bit, error: ", m_last_WSA_error);
         #endif
         return;
      }
   }
}

// Helper function that sets up event-handling on a socket
void ClientSocket::SetupSocketEventHandling() {
   #ifdef SOCKET_LIBRARY_USE_EVENTS
   
      // First, if we're done checking for event handling then return now
      if (m_done_event_handling) {
         return;
      }   
      
      // Next, only do event handling in an EA. Ignore otherwise.
      if (MQLInfoInteger(MQL_PROGRAM_TYPE) != PROGRAM_EXPERT) {
         m_done_event_handling = true;
         return;
      }
      
      // Now, attempt to get the handle of the chart associated with this EA. If we don't
      // find it then return now
      long handle = ChartGetInteger(0, CHART_WINDOW_HANDLE);
      if (!handle) {
         return;
      }
      
      // Finally, set the event handling flag to true and setup the async handler
      m_done_event_handling = true; 
      if (TerminalInfoInteger(TERMINAL_X64)) {
         WSAAsyncSelect(m_socket64, handle, 0x100 /* WM_KEYDOWN */, 0xFF /* All events */);
      } else {
         WSAAsyncSelect(m_socket32, (int)handle, 0x100 /* WM_KEYDOWN */, 0xFF /* All events */);
      }
   #endif
}

// Helper function that attempts to send data on a character buffer with a given length on the socket
//    data:    The data to be sent
//    length:  The length of data to be send on the socket
bool ClientSocket::SendInner(uchar &data[], int length) {
   bool retVal = true;
   while (length > 0) {
   
      // First, calculate the length of the data we'll send to the socket
      int res, buffer = (length > SendBufferSize ? SendBufferSize : length);
      
      // Next, send the data on the socket and receive the response code
      if (TerminalInfoInteger(TERMINAL_X64)) {
         res = send(m_socket64, data, buffer, 0);
      } else {
         res = send(m_socket32, data, buffer, 0);
      }
      
      // Finally, check the response code. If it's an error then record it and disconnect
      // from the socket; otherwise, resize the data so we can send the next chunk
      if (res == SOCKET_ERROR || res == 0) {
         m_last_WSA_error = WSAGetLastError();
         if (m_last_WSA_error == WSAWOULDBLOCK) {
            // Blocking operation. Retry.
         } else {
            #ifdef SOCKET_LIBRARY_LOGGING
               Print("send() failed, error: ", m_last_WSA_error);
            #endif

            // Assume death of socket for any other type of error
            length = -1;
            retVal = false;
            m_connected = false;
         }
      } else {
         length -= res;
         if (length > 0) {
         
            // If further data remains to be sent, shuffle the array downwards
            // by copying it onto itself. Note that the MQL4/5 documentation
            // says that the result of this is "undefined", but it seems
            // to work reliably in real life (because it almost certainly
            // just translates inside MT4/5 into a simple call to RtlMoveMemory,
            // which does allow overlapping source & destination).
            ArrayCopy(data, data, 0, res, length);
         }
      }
   }

   return retVal;
}

// Helper function that receives data into a buffer from the socket
//    results:    The data that will hold the data we received
int ClientSocket::ReceiveInner(uchar &results[]) {

   // First, check whether we're working with a 64-bit or 32-bit system
   bool is64 = TerminalInfoInteger(TERMINAL_X64);

   // Next, setup the socket to receive
   uint nonblock = 1;
   if (is64) {
      ioctlsocket(m_socket64, FIONBIO, nonblock);
   } else {
      ioctlsocket(m_socket32, FIONBIO, nonblock);
   }

   // Now, setup a buffer to retrieve data
   uchar buffer[];
   ArrayResize(buffer, ReceiveBufferSize);

   // Finally, receive data on the buffer until we don't receive anymore
   int res = 1;
   int total = 0;
   while (res > 0) {
   
      // Attempt to receive at the socket; record the response
      if (is64) {
         res = recv(m_socket64, buffer, ReceiveBufferSize, 0);
      } else {
         res = recv(m_socket32, buffer, ReceiveBufferSize, 0);
      }
   
      // If the response is greater than zero then we've retrieve data so add it
      // to the buffer. Otherwise, if the response is zero then the socket is closed.
      // Finally, if the response is less than zero then we have an error so log
      // it and return
      if (res > 0) {
         ArrayResize(results, total + res);
         ArrayCopy(results, buffer, total, 0, res);
         total += res;
      } else if (res == 0) {
	    #ifdef SOCKET_LIBRARY_LOGGING
		   Print("Socket closed");
	    #endif
	    m_connected = false;
      } else {
         m_last_WSA_error = WSAGetLastError();
         if (m_last_WSA_error != WSAWOULDBLOCK) {
            #ifdef SOCKET_LIBRARY_LOGGING
               Print("recv() failed, result:, " , res, ", error: ", m_last_WSA_error);
            #endif
            m_connected = false;
         }
      }
   }
   
   return total;
}
