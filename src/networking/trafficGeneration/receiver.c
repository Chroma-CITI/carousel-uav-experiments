#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <pthread.h>
#include <chrono>
#include <arpa/inet.h>
#include <iostream>

#define MAXBUFF_SIZE 65507

typedef struct { 

	int sockfd;
	char * buffer;
	size_t buffersize;
	int flags;
	struct sockaddr_in clientAddr;
	int size;
    int mode;

} recvThreadStruct;

void erreur(char* string, int exit_status)
{
	perror(string);
	exit(exit_status);
}


static int open_rcv_socket(uint16_t port, int mode, recvThreadStruct netInfo){
    int sockfd;
    struct sockaddr_in address;
    
    // Creating socket file descriptor
    if  (mode == 0 ){
        sockfd = socket(AF_INET, SOCK_STREAM, 0);
    }
    
    else if  (mode == 1 ){
        sockfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    }

        if ( sockfd == -1)
	{
		std::cout << "Erreur création socket : " << std::endl;
		return -2;
	}
	
    memset(&address, 0, sizeof(address));

    address.sin_family = AF_INET;
    address.sin_port = htons(port);
    address.sin_addr.s_addr = INADDR_ANY;

        // Bind the socket with the address
    if ( bind(sockfd, (const struct sockaddr *)&address, 
            sizeof(address)) < 0 )
    {
        perror("bind failed");
        return -1;
    }

    netInfo.sockfd = sockfd;
    netInfo.clientAddr = address;
    return sockfd;
}


void receptionLoop(int sockfd, char * buffer, size_t buffersize, int flags, struct sockaddr_in clientAddr, int size, int mode){

    int nbBytes;
    
    while (1){
        
        if ( mode == 0 ){ // TCP
            nbBytes=recvfrom(sockfd, buffer, buffersize, 0, NULL, NULL);
        }
        else if ( mode == 1 ){ // UDP
            nbBytes=recvfrom(sockfd, buffer, buffersize, 0, (struct sockaddr *)  &clientAddr, (socklen_t *) &size);
        }
        
        printf ("msg (%d) : %s \n",nbBytes,buffer);
    }
    

}

// Fonction appelée par le thread
void* threadrcv( void* _r){
	recvThreadStruct r;
	r = *(recvThreadStruct*) _r;

	receptionLoop(r.sockfd, r.buffer, r.buffersize, r.flags, r.clientAddr, r.size,r.mode);
}


int main(int argc, char* argv[])
{

    
    std::chrono::duration<double> reportTime;
    int mode; // mode=0 pour TCP et mode=1 pour UDP
    int sockfd;

    
    
    if (argc != 2 ){
        fprintf(stderr,"Usage: \n\t arg 1 : mode 0 for TCP 1 for UDP\n");
        exit(-1);
        
    }
    
    mode = atoi(argv[1]);
    unsigned short port = 7777;
    pthread_t threadId;
    struct sockaddr_in from;
    socklen_t fromlen = sizeof(from);
    char buffer[1000] = { 0 };
	        
    recvThreadStruct recvStruct;
    
    sockfd=open_rcv_socket(port,mode,recvStruct);

    recvStruct.sockfd =sockfd;
	recvStruct.buffer =buffer;
	recvStruct.buffersize=1000;
	recvStruct.flags =0;
	recvStruct.clientAddr = recvStruct.clientAddr;
	recvStruct.size = sizeof(recvStruct.clientAddr);
    
    if (mode == 0 ){ // if TCP
        
        if(listen(sockfd, 5) == -1)
        {
            perror("listen()");
            exit(errno);
        }
                
        int csock = accept(sockfd, (struct sockaddr *)&from, &fromlen);

        if(csock == -1)
        {
            perror("accept()");
            exit(errno);
        }
        recvStruct.sockfd =csock;
        
        printf(" fin spécifique TCP\n");
        
    }
    
    
    pthread_create(&threadId, NULL, threadrcv, &recvStruct);

    auto start = std::chrono::steady_clock::now();
    auto now = std::chrono::steady_clock::now();
    std::chrono::duration<double> elapsed;

//  This section is an example to print repport on number of received bytes, Throughput and losses    
	while(1){
        
	}



	return 0;
}

