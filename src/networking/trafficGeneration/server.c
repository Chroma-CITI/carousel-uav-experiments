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
#include <arpa/inet.h>

//Only cpp libs ... should we go all C instead ?
#include <chrono>
#include <iostream>

#define MAXBUFF_SIZE 65507

// Global variable not very clean but very handy
// Should be cleaned if the code is not used in a stand-alone way

unsigned int totalrcvd = 0; 
unsigned long int rcvdBytes = 0; 

unsigned int lastSeq = 0; 

unsigned int receivedMessages = 0; 
unsigned int totalReceivedMessages = 0;

unsigned int loss = 0;
unsigned int totalLoss = 0;

unsigned int totalUnordered = 0;
unsigned int unordered = 0;

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


void receptionLoop(int sockfd, char * buffer, size_t buffersize, int flags, struct sockaddr_in clientAddr, int size, int mode){

	int nbBytes;
    int seq;
    while (1){
        
        if ( mode == 0 ){ // TCP
            nbBytes = recv(sockfd, buffer, sizeof buffer - 1, 0);
        }
        else if ( mode == 1 ){ // UDP
            nbBytes=recvfrom(sockfd, buffer, buffersize, 0, (struct sockaddr *)  &clientAddr, (socklen_t *) &size);
        }
        
		totalrcvd+=nbBytes;
		rcvdBytes+=nbBytes;     
        receivedMessages++;
        totalReceivedMessages++;
        
        seq=atoi(buffer);
        
        if (seq == lastSeq+1){
//             printf("isok\n");
        }
        else if ( seq > lastSeq+1 ){
         // Perte de message
            loss+=(seq-lastSeq)-1;
            totalLoss+=(seq-lastSeq)-1;
//             printf("perte\n");
        }
        else if ( seq < lastSeq ){
            unordered++;
            totalUnordered++;
        }

        lastSeq=seq;
    }
    

}


// Function called by the tread
void* threadrcv( void* _r){

	recvThreadStruct r;
	r = *(recvThreadStruct*) _r;

	receptionLoop(r.sockfd, r.buffer, r.buffersize, r.flags, r.clientAddr, r.size,r.mode);
}


int main(int argc, char* argv[])
{

    
    std::chrono::duration<double> reportTime;
    int mode; // mode=0 for TCP and mode=1 for UDP
    int sockfd;

    
    
    if (argc != 3 ){
        fprintf(stderr,"Usage: \n\t arg 1 : Report delay \n\t arg 2 : mode 0 for TCP 1 for UDP\n");
        exit(-1);
        
    }
    
    
    reportTime = std::chrono::duration<double>(atof(argv[1])) ;
    mode = atoi(argv[2]);

    system(" echo -n 'date ' ; date +%s%N");

       
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

	unsigned short port = 7777;
    pthread_t threadId;

    
	struct sockaddr_in addr;
	addr.sin_addr.s_addr = INADDR_ANY;
	addr.sin_port = htons(port);
	addr.sin_family = AF_INET;
	if (bind(sockfd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) != 0)
	{
		std::cout << "Erreur bind socket : " << std::endl;
		return -3;
	}

    struct sockaddr_in from;
    socklen_t fromlen = sizeof(from);
    char buffer[1500] = { 0 };
	    

    // Struct for passing several parameters to the thread call
    recvThreadStruct recvStruct;
    
    recvStruct.sockfd =sockfd;
	recvStruct.buffer =buffer;
	recvStruct.buffersize=MAXBUFF_SIZE;
	recvStruct.flags =0;
	recvStruct.clientAddr = from;
	recvStruct.size = fromlen;
    recvStruct.mode = mode;
    
    
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
    
	while(1){
		now = std::chrono::steady_clock::now();
		elapsed = now - start;
		
		if ( elapsed >= reportTime ){
			printf("####################################################\n");
            printf("From beginning \n");
            printf("\tBytes received : %u \n",totalrcvd);
            printf("\tNumber of message : %d \n",totalReceivedMessages);
            printf("\tNumber of loss : %d (%f) \n",totalLoss,(float)totalLoss/totalReceivedMessages);
            printf("\tNumber of unordered receptions : %d \n",totalUnordered);
            printf("----------------------------------------------------\n");
            printf("From last %lf secondes\n",reportTime);
            printf("\tBytes received : %lu \n",rcvdBytes);
            printf ("\t Throughput : %lf bytes/s ( %lf MB/s ) \n",rcvdBytes/elapsed.count(), rcvdBytes/elapsed.count()/1000000);
            printf("\tNumber of message : %d \n",receivedMessages);
            printf("\tNumber of loss : %d (%f) \n",loss,(float)loss/receivedMessages);
            printf("\tNumber of unordered receptions : %d \n",unordered);
            printf("####################################################\n\n");
			start=now;
            
            //Reseting report counters
			rcvdBytes=0;
            receivedMessages=0;
            loss=0;
            unordered=0;
		}
		
	}



	return 0;
}

