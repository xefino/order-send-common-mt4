#property copyright "Xefino"
#property version   "1.08"
#property strict

#include "ClientSocket.mqh"
#include "SocketCommon.mqh"

// ServerSocket
// Object allowing for the creation of a socket server
class ServerSocket {
private:

   // Need different socket handles for 32-bit and 64-bit environments
   SOCKET_HANDLE32   m_socket32;
   SOCKET_HANDLE64   m_socket64;
   bool              m_created;              // Whether or not the connection was created
   int               m_last_WSA_error;       // The last WSA error we received
   bool              m_done_event_handling;  // Whether we're still handling events
   
   // Helper function that sets up event-handling on a socket
   void SetupSocketEventHandling();
              
public:

   // Constructor, specifying whether we allow remote connections
   //    port:       The port number to listen on
   //    localOnly:  Whether or not the server should listen locally or remotely
   ServerSocket(const ushort port, const bool localOnly);
   
   // Destructor that frees up resources associated with the socket server
   ~ServerSocket();
   
   // Accepts any incoming connection. Returns either NULL, or an instance of ClientSocket
   ClientSocket *Accept();

   // IsCreated returns whether or not the socket server has been created
   bool IsCreated() const { return m_created; }
   
   // LastError returns the last error code recorded on the socket connection
   int LastError() const { return m_last_WSA_error; }
   
   // Handle returns the socket handle associated with this connection
   ulong Handle() const { return (m_socket32 ? m_socket32 : m_socket64); }
};

// Constructor, specifying whether we allow remote connections
//    port:       The port number to listen on
//    localOnly:  Whether or not the server should listen locally or remotely
ServerSocket::ServerSocket(const ushort port, const bool localOnly) {
   #ifdef SOCKET_LIBRARY_LOGGING
      Print("Socket logging enabled");
   #endif
   
   // First, attempt to create the socket and make it non-blocking
   m_created = false;
   m_last_WSA_error = 0;
   if (TerminalInfoInteger(TERMINAL_X64)) {
   
      // Force compiler to use the 64-bit version of socket() by passing it a uint 3rd parameter 
      m_socket64 = socket(AF_INET, SOCK_STREAM, (uint)IPPROTO_TCP);
      if (m_socket64 == INVALID_SOCKET64) {
         m_last_WSA_error = WSAGetLastError();
         #ifdef SOCKET_LIBRARY_LOGGING
            Print("socket() failed, 64-bit, error: ", m_last_WSA_error);
         #endif
         return;
      }
      
      // Attempt to create a socket connection
      uint nonblock = 1;
      ioctlsocket(m_socket64, FIONBIO, nonblock);
   } else {
   
      // Force compiler to use the 32-bit version of socket() by passing it a int 3rd parameter 
      m_socket32 = socket(AF_INET, SOCK_STREAM, (int)IPPROTO_TCP);
      if (m_socket32 == INVALID_SOCKET32) {
         m_last_WSA_error = WSAGetLastError();
         #ifdef SOCKET_LIBRARY_LOGGING
            Print("socket() failed, 32-bit, error: ", m_last_WSA_error);
         #endif
         return;
      }
      
      // Attempt to create a socket connection
      uint nonblock = 1;
      ioctlsocket(m_socket32, FIONBIO, nonblock);
   }
   
   // Create a new sock address from the port and server address
   sockaddr server;
   server.family = AF_INET;
   server.port = htons(port);
   server.address = (localOnly ? 0x100007f : 0); // 127.0.0.1 or INADDR_ANY

   // Create a flag determining if this socket should be a 32-bit or 64-bit socket
   bool is64 = TerminalInfoInteger(TERMINAL_X64);
   string asStr = is64 ? "64" : "32";
   
   // Next, attempt to bind to the socket; if this fails then print an error and exit
   int bindres = is64 ? 
      bind(m_socket64, server, sizeof(sockaddr)) :
      bind(m_socket32, server, sizeof(sockaddr));
   if (bindres != 0) {
      m_last_WSA_error = WSAGetLastError();
      #ifdef SOCKET_LIBRARY_LOGGING
         Print("bind() failed, ", asStr, "-bit, port probably already in use, error: ", m_last_WSA_error);
      #endif
      return;
   }
   
   // Now, attempt to listen on the socket; if this fails then print an error and eiit
   int listenres = is64 ? listen(m_socket64, 10) : listen(m_socket32, 10);
   if (listenres != 0) {
      m_last_WSA_error = WSAGetLastError();
      #ifdef SOCKET_LIBRARY_LOGGING
         Print("listen() failed, ", asStr, "-bit, error: ", m_last_WSA_error);
      #endif
      return;
   }
   
   // Finally, if we've reached this point then our socket connection was successful so
   // set our created flag to true
   m_created = true;
   
   // Try settig up event handling; can fail here in constructor
   // if no window handle is available because it's being called 
   // from OnInit() while MT4/5 is loading
   #ifdef SOCKET_LIBRARY_USE_EVENTS
      SetupSocketEventHandling();
   #endif
}

// Destructor that frees up resources associated with the socket server
ServerSocket::~ServerSocket() {
   if (TerminalInfoInteger(TERMINAL_X64)) {
      if (m_socket64 != 0) {
         closesocket(m_socket64);
      }
   } else {
      if (m_socket32 != 0) {
         closesocket(m_socket32);
      }
   }   
}

// Accepts any incoming connection. Returns either NULL, or an instance of ClientSocket
ClientSocket *ServerSocket::Accept() {

   // First, if the connection hasn't been created then return NULL here
   if (!m_created) {
      return NULL;
   }
   
   // Next, make sure that event handling is in place; can fail in constructor if no window handle
   // is available because it's being called from OnInit() while MT4/5 is loading
   #ifdef SOCKET_LIBRARY_USE_EVENTS
      SetupSocketEventHandling();
   #endif
   
   // Finally, attempt to accept the connection on the socket and then generate a client socket from
   // that accepted connection
   ClientSocket *pClient = NULL;
   if (TerminalInfoInteger(TERMINAL_X64)) {
      SOCKET_HANDLE64 acc = accept(m_socket64, 0, 0);
      if (acc != INVALID_SOCKET64) {
         pClient = new ClientSocket(acc);
      }
   } else {
      SOCKET_HANDLE32 acc = accept(m_socket32, 0, 0);
      if (acc != INVALID_SOCKET32) {
         pClient = new ClientSocket(acc);
      }
   }

   return pClient;
}

// Helper function that sets up event-handling on a socket
void ServerSocket::SetupSocketEventHandling() {
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
      
   int errCode = GetLastError();
   if (errCode != 0) {
      Print("Error 5: ", errCode);
      ResetLastError();
   }
   #endif
}