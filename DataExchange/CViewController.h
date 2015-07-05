//
//  CViewController.h
//  DataExchange
//
//  Created by morimotor on 12/12/11.
//  Copyright (c) 2012年 morimotor. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <sys/socket.h>
#import <sys/ioctl.h>
#import <net/if.h>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <unistd.h>
#import <sys/types.h>

#import <netdb.h>

#define LOG(x) [self performSelectorOnMainThread:@selector(LogOutput:) withObject:x waitUntilDone:NO];

#define Port "12345"
#define IP1 "端末1のIPv6アドレスを入れる"  // 1のアドレス
#define IP2 "端末2のIPv6アドレスをいれる"  // 2のアドレス

#define RESENDTIME 5

#define BUFFSIZEP 6003
#define BUFFSIZE  6000

enum type
{
    FTEXT=0,    // 通常のテキスト
    FIMG,       // 画像
    FMESI,      // 画像情報
    FMESR       // 受信完了
};

@interface CViewController : UIViewController<UINavigationControllerDelegate, UIImagePickerControllerDelegate>
{
    IBOutlet UIImageView* recvImg;
    IBOutlet UIImageView* sendImg;
    
    IBOutlet UITextView* logText;
    IBOutlet UITextView* sendText;
    IBOutlet UITextView* recvText;
    
    IBOutlet UITextField* sock1Addr;
    IBOutlet UITextField* sock2Addr;
    
    IBOutlet UILabel* fifoNum;
    
    UIImagePickerController* imagePicker;
    UIImage* nullImg;
    
    NSMutableString* logString;
    
    float timer;    // 送信スレッドのタイマー
    
    // UDP
    int sendSocket;
    int recieveSocket;
    struct addrinfo hints, *res;    // 送信
    struct sockaddr_in6 recieveAddr;
    int ctr;
    NSString* recvStr;  // 最後に受信した文字列
    int recv_flag;  // 新しく受信したかどうか
    NSMutableArray *fifo;
    int nextSendFlag;   // 相手から受信完了メッセージがきたかどうかのフラグ。受信完了の場合を送信する
    int preMesseageID;  // 前回送信したデータのID(受信完了のメッセージと比較させてデータの送信を確認する)
    int imgRecvFlag;    // 画像の受信中フラグ
    int imageSize;  // 受信画像のサイズ
    int recv_img_num;   // 受信中の画像num
    int recv_img_num_max; //受信画像の分割数
    UIImage *recv_img;  // 受信した画像

}

@property(nonatomic, retain)UIImageView* recvImg;
@property(nonatomic, retain)UIImageView* sendImg;
@property(nonatomic, retain)UITextView* logText;
@property(nonatomic, retain)UITextView* sendText;
@property(nonatomic, retain)UITextView* recvText;
@property(nonatomic, retain)UITextField* sock1Addr;
@property(nonatomic, retain)UITextField* sock2Addr;
@property(nonatomic, retain)UILabel* fifoNum;

-(IBAction)createSock1:(id)sender;
-(IBAction)createSock2:(id)sender;
-(IBAction)camera:(id)sender;
-(IBAction)sendImg:(id)sender;
-(IBAction)saveSendImg:(id)sender;
-(IBAction)saveRecvImg:(id)sender;
-(IBAction)removeSendImg:(id)sender;
-(IBAction)removeRecvImg:(id)sender;
-(IBAction)sendText:(id)sender;
-(IBAction)clearText:(id)sender;

@end
