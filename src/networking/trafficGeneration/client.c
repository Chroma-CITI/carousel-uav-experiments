#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

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

// Only libs in cpp should we stay C only ?
#include <chrono>
#include <iostream>

#define MAXBUFF_SIZE 65507

// Global variables : not very clean but way easier to use. 
// Should change that in case of code reuse in another context

unsigned totalPktSent = 0;
unsigned pktSent = 0;

unsigned totalByteSent = 0;
unsigned byteSent = 0;

unsigned int loss = 0; // Number of missing sequence number from last report
unsigned int totalLoss = 0; // Number of missing sequence number from beginning


typedef struct { 

	int sockfd;
	struct sockaddr_in to;
	useconds_t delay;
	int size;
    int mode;

} sendThreadStruct;


void setSequenceNumber(char* _buff){
    
    sprintf(_buff,"%u",totalPktSent);    
}

void erreur(char* string, int exit_status)
{
	perror(string);
	exit(exit_status);
}


ssize_t sendRate(int _sockfd, const struct sockaddr_in _to,useconds_t _delay,unsigned int _pktSize, int mode){
	ssize_t r;
	
    int maxNoiseSize = 0;
    int maxNoiseDelay = 0;
    
    int maxSize = _pktSize+maxNoiseSize;
    int minSize = _pktSize-maxNoiseSize;

    int maxDelay = _delay+maxNoiseDelay;
    int minDelay = _delay-maxNoiseDelay;

    if (minSize < 0) { minSize =0;}
    if (minDelay < 0) { minDelay =0;}
    
    //srand intialize the RNG, can be seeded
    srand(time(0));
    
        
    char buffFull[maxSize];
	memset(buffFull,0,maxSize);
    
	
	while (1){
        
        
        int pktSize = ( rand() % (maxSize-minSize +1) + minSize ) ;  
        char _buff[pktSize];
        setSequenceNumber(_buff);
        
        useconds_t delay = ( rand() % (maxDelay-minDelay +1) + minDelay) ;
        
        if (mode == 1) {
            r =  sendto(_sockfd, _buff, sizeof(_buff), 0,reinterpret_cast<const sockaddr*>(&_to), sizeof(_to));
        }
        else if (mode == 0) {
            r = send(_sockfd, _buff, sizeof(_buff), 0);
        }
            
        
        if(r != sizeof(_buff)){ 
			erreur("Erreur sendto",2);
		}
        
		// Global stats
		totalByteSent+=r;
		byteSent+=r;
		pktSent++;
		totalPktSent++;
		usleep(delay);
	
	}
	
	return r;
}

// Function call by thread
void* threadSend( void* _s){
    
    sendThreadStruct s ;
    s =*(sendThreadStruct*) _s;
    sendRate(s.sockfd,s.to,s.delay,s.size,s.mode);
        
}

int main(int argc, char* argv[])
{
    
    if(argc != 5 ){
		fprintf(stderr,"Usage: \n\t arg 1 : paquet size in octet \n\t arg 2 : delay in us \n\t arg 3 : destination \n\t arg 4 mode : mode 0 for TCP 1 for UDP\n ");
		exit(1);
	}

    unsigned short port = 1337;
    
	unsigned int pktSize;
	useconds_t delay;
    char destination[100]="";

    int mode; // mode=0 for TCP and mode=1 for UDP

    pktSize = atoi(argv[1]);
    delay = atof(argv[2]);
    strcpy(destination,argv[3]);
    mode = atoi(argv[4]);

	int sockfd;
    
    printf("Throughput asked : %lf Bytes/s ( %lf MB/s ) \n",(double)pktSize/(delay/1000000),(double)pktSize/(delay) );
    system(" echo -n 'date ' ; date +%s%N ;");
    

    
    if  (mode == 0 ){
        sockfd = socket(AF_INET, SOCK_STREAM, 0);
    }
    else if  (mode == 1 ){
        sockfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    }
        
	if (sockfd == -1)
	{
		std::cout << "Erreur création socket : " << std::endl;
		return -2;
	}

	struct sockaddr_in addr;
	addr.sin_addr.s_addr = INADDR_ANY;
	addr.sin_port = htons(port);
	addr.sin_family = AF_INET;
    
	if (bind(sockfd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) != 0)
	{
		std::cout << "Erreur bind socket : " << std::endl;
		return -3;
	}

	unsigned short portDst = 7777;
	struct sockaddr_in to = { 0 };
	inet_pton(AF_INET, destination, &to.sin_addr.s_addr);
	to.sin_family = AF_INET;
	to.sin_port = htons(portDst);
    
    
    if (mode == 0) { /// if TCP
        
        if(connect(sockfd,(struct sockaddr *) &to, sizeof(struct sockaddr)) == -1)
        {
            perror("connect()");
            exit(errno);
        }

    }

    sendThreadStruct sendStruct;
    sendStruct.sockfd=sockfd;
    sendStruct.to=to;
    sendStruct.delay=delay;
    sendStruct.size=pktSize;
    sendStruct.mode=mode;
        
    pthread_t threadId;
    pthread_create(&threadId, NULL, threadSend, &sendStruct);
    
    auto start = std::chrono::steady_clock::now();
    auto now = std::chrono::steady_clock::now();
    std::chrono::duration<double> elapsed;
    
    //Should be a main arg
    std::chrono::duration<double> reportTime;
    reportTime = std::chrono::duration<double>(1.0);

    
	while(1){
		now = std::chrono::steady_clock::now();
		elapsed = now - start;
		
		if ( elapsed >= reportTime ){
			printf("####################################################\n");
            printf("From beginning \n");
            printf("\tBytes send : %u \n",totalByteSent);
            printf("\tNumber of message : %d \n",totalPktSent);
            printf("----------------------------------------------------\n");
            printf("From last %lf secondes\n",reportTime);
            printf("\tBytes send : %u \n",byteSent);
            printf("\tNumber of message : %d \n",pktSent);
			printf ("\t Throughput : %lf bytes/s ( %lf MB/s ) \n",byteSent/elapsed.count(), byteSent/elapsed.count()/1000000);
            printf("####################################################\n\n");
			start=now;
            
            //Restarting report counters  
			byteSent=0;
            pktSent=0;
            pktSent=0;
            
		}
		
	}
        
        

	return 0;
}

