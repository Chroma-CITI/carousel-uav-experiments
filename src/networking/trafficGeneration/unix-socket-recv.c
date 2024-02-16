/*
* This code read the UDS socket named "/tmp/my-unix-sock"
* and send everything it receives on a UDP or TCP socket
*
*/

#define SOCKET_NAME "/tmp/my-unix-sock"
#define BUFFER_SIZE 1000

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <unistd.h>
#include <sys/types.h>
#include <netinet/in.h>
#include <netdb.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <errno.h>
#include <arpa/inet.h>

void setData(char _buff[BUFFER_SIZE], char _dist[BUFFER_SIZE]){
    memset(_buff,0,BUFFER_SIZE);
    sprintf(_buff,"%s\n",_dist); 
}

void erreur(char* string, int exit_status)
{
	perror(string);
	exit(exit_status);
}

 struct netInfo {
     int _sockfd; 
     struct sockaddr_in _to;
     
 };
 
ssize_t sendDist(struct netInfo _info, int mode,char _dist[BUFFER_SIZE]){
	ssize_t r;
    
    int _sockfd = _info._sockfd;
    struct sockaddr_in to = _info._to;
        
        char _buff[BUFFER_SIZE];
        setData(_buff,_dist);
                
        if (mode == 1) { //UDP
            r =  sendto(_sockfd, _buff, sizeof(_buff), 0,(struct sockaddr*)&to, sizeof(to));
        }
        else if (mode == 0) { //TCP
            r = send(_sockfd, _buff, sizeof(_buff), 0);
        }
            
        
        if(r != sizeof(_buff)){ 
			erreur("Erreur sendto",2);
		}
		
	return r;
}


struct netInfo netSetup(int mode, char destination[100])
{
    // mode=0 for TCP and mode=1 for UDP
    struct netInfo info;
    
    unsigned short port = 1337;

	int sockfd;
    
    if  (mode == 0 ){
        sockfd = socket(AF_INET, SOCK_STREAM, 0);
    }
    else if  (mode == 1 ){
        sockfd = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);
    }
        
	if (sockfd == -1)
	{
        printf("Erreur création socket : ");
		exit(-2);
	}

    
	struct sockaddr_in addr;
	addr.sin_addr.s_addr = INADDR_ANY;
	addr.sin_port = htons(port);
	addr.sin_family = AF_INET;

	int broadcastEnable=1;
    int ret=setsockopt(sockfd, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, sizeof(broadcastEnable));    
    
	if (bind(sockfd, (struct sockaddr*)(&addr), sizeof(addr)) != 0)
	{
        printf("Erreur bind socket : ");
        
		exit(-3);
	}

	unsigned short portDst = 7777;

	struct sockaddr_in to = { 0 };
    printf("dest : %s\n",destination);
 	inet_pton(AF_INET, destination, &to.sin_addr.s_addr);
	to.sin_family = AF_INET;
	to.sin_port = htons(portDst);
//     to.sin_addr.s_addr = inet_destination;// TODO addr sub-net ?

    
    if (mode == 0) { /// if TCP
        
        if(connect(sockfd,(struct sockaddr *) &to, sizeof(struct sockaddr)) == -1)
        {
            perror("connect()");
            exit(errno);
        }
    }
        
    info._sockfd=sockfd;
    info._to=to;
    
	return info;

}

/*****
 End of the network part 
    netSetup and sendDist are called in the main section
 *****/

int main(int argc, char *argv[])
{
    struct sockaddr_un addr;
    int down_flag = 0;
    int ret;
    int listen_socket;
    int data_socket;
    char buffer[BUFFER_SIZE];
    char destination[100]="";

    
    if (argc != 3 ){
        fprintf(stderr,"Usage: \n\t arg 1 : mode 0 for TCP 1 for UDP\n arg2 : destination\n");
        exit(-1);
        
    }

    int mode = atoi(argv[1]);
    strcpy(destination,argv[2]);

    
    /*
     * In case the program exited inadvertently on the last run,
     * remove the socket.
     */

    unlink(SOCKET_NAME);

    /* Create local socket. */

    listen_socket = socket(AF_UNIX, SOCK_STREAM, 0);
    if (listen_socket == -1) {
        perror("socket");
        exit(EXIT_FAILURE);
    }

    /*
     * For portability clear the whole structure, since some
     * implementations have additional (nonstandard) fields in
     * the structure.
     */

    memset(&addr, 0, sizeof(struct sockaddr_un));

    /* Bind socket to socket name. */
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCKET_NAME, sizeof(addr.sun_path) - 1);

    ret = bind(listen_socket, (const struct sockaddr *) &addr,sizeof(struct sockaddr_un));
    if (ret == -1) {
        perror("bind");
        exit(EXIT_FAILURE);
    }

    /*
     * Prepare for accepting connections. The backlog size is set
     * to 20. So while one request is being processed other requests
     * can be waiting.
     */

    ret = listen(listen_socket, 20);
    if (ret == -1) {
        perror("listen");
        exit(EXIT_FAILURE);
    }

        /* Wait for incoming connection. */

        data_socket = accept(listen_socket, NULL, NULL);
        if (data_socket == -1) {
            perror("accept");
            exit(EXIT_FAILURE);
        }

        
            struct netInfo networkInfo = netSetup(mode,destination);

        
        while (1){

            /* Wait for next data packet. */
            ret = read(data_socket, buffer, BUFFER_SIZE);
            if (ret == -1) {
                perror("read");
                exit(EXIT_FAILURE);
            }
            if (ret == -1) {
                perror("write");
                exit(EXIT_FAILURE);
            }
            printf("%s\n",buffer);
            sendDist(networkInfo,mode,buffer);

        }
            
        /* Close socket. */

        close(data_socket);



    close(listen_socket);

    /* Unlink the socket. */

    unlink(SOCKET_NAME);

    exit(EXIT_SUCCESS);
}
