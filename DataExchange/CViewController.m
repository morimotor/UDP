//
//  CViewController.m
//  DataExchange
//
//  Created by morimotor on 12/12/11.
//  Copyright (c) 2012年 morimotor. All rights reserved.
//

#import "CViewController.h"
@interface CViewController ()

@end

@implementation CViewController
@synthesize recvImg;
@synthesize sendImg;
@synthesize logText;
@synthesize sendText;
@synthesize recvText;
@synthesize sock1Addr;
@synthesize sock2Addr;
@synthesize fifoNum;

// 初期化
- (void)viewDidLoad
{
    [super viewDidLoad];
	
    sock1Addr.text = [NSString stringWithFormat:@"%s", IP1];
    sock2Addr.text = [NSString stringWithFormat:@"%s", IP2];
    
    nullImg= [UIImage imageNamed:@"img.png"];
    recvImg.image = nullImg;
    sendImg.image = nullImg;
    
    imagePicker = [[UIImagePickerController alloc] init];
	imagePicker.delegate = self;
    
    logString =  [NSMutableString string];
    logText.editable = NO;
    recvText.editable = NO;
    
    sendText.text = @"てすと";
    
    fifo = [[NSMutableArray alloc]init];
    
    LOG(@"初期化完了");
    
    [self createRecieve];
}


-(IBAction)createSock1:(id)sender
{
    [self createSend:IP1];
}


-(IBAction)createSock2:(id)sender
{
    [self createSend:IP2];
}

// UDP送信ソケット作成
-(void)createSend:(char *)ip
{
    // 送信
    sendSocket = -1;
    
    // ネットワークアドレス
    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_INET6;
    hints.ai_socktype = SOCK_DGRAM;
    getaddrinfo(ip, Port, &hints, &res);
    
    sendSocket = socket(res->ai_family, res->ai_socktype, 0);
    
    
    if(sendSocket < 0)
    {
        LOG(@"■送信ソケット作成失敗");
        return;
    }
    
    NSString* str = [NSString stringWithFormat:@"送信ソケット作成 %s", ip];
    LOG(str);
    
    static int a = 0;
    if(a==0)[NSThread detachNewThreadSelector:@selector(sendThread) toTarget:self withObject:nil];
    a=1;
}

// UDP受信ソケット作成
-(void)createRecieve
{
    recieveSocket = -1;
    recieveSocket = socket(AF_INET6, SOCK_DGRAM, 0);
    
    if(recieveSocket<0)
    {
        LOG(@"■受信ソケット作成失敗");
        return;
    }
    
    LOG(@"受信ソケット作成");
    
    // ネットワークのアドレス
    recieveAddr.sin6_addr = in6addr_any;
    recieveAddr.sin6_port = htons(atoi(Port));
    recieveAddr.sin6_family = AF_INET6;
    
    const int one = 1;
    setsockopt(recieveSocket, SOL_SOCKET, SO_REUSEADDR, &one, sizeof(int));
    
    // ソケットのバインド
    int rt = bind(recieveSocket, (struct sockaddr*)&recieveAddr, sizeof(recieveAddr));
    if(rt < 0)
    {
        perror("recieveSocket");
        LOG(@"■バインド失敗");
        return;
    }
    
    LOG(@"バインド成功");
    
    static int a=0;
    // スレッドを投げる
    if(a==0)[NSThread detachNewThreadSelector:@selector(recieveThread) toTarget:self withObject:nil];
    a=1;
}

// 送信スレッド
-(void)sendThread
{
    timer = 0.0f;
    
    while(1)
    {
        
        float settime = 0.001f;
        
        if(nextSendFlag==FALSE)[NSThread sleepForTimeInterval:settime];
        
        timer+=settime;
        if(timer >= RESENDTIME)
        {
            nextSendFlag=TRUE;
            timer = 0.0f;
        }
        
        if([fifo count]==0)continue;
        if(!nextSendFlag)continue;
        
        nextSendFlag=FALSE;
        unsigned char buff[BUFFSIZEP];
        memset(buff, 0, BUFFSIZEP);
        
        // ワイドバイト（日本語など）での送信に対応させるNSString->NSData->char->send
        [NSThread sleepForTimeInterval:0.02];
        NSMutableArray *arr = [fifo objectAtIndex:0];
        NSData* msg = [arr objectAtIndex:3];
        [msg getBytes:buff];
        
        unsigned int r = [[arr objectAtIndex:1]intValue];
        unsigned char num = [[arr objectAtIndex:2]unsignedCharValue];
        char kind = [[arr objectAtIndex:0]unsignedCharValue];
        
        [self setTagMessage:buff kind:kind Id:r number:num];
        
        int l = (int)sizeof(buff);
        
        int rt = sendto(sendSocket, buff, l+1, 0, (struct sockaddr*)(res->ai_addr), res->ai_addrlen);
        
        if(rt != l+1)
        {
            perror("send");
            LOG(@"■送信失敗");
            
            return;
        }
        
        if(kind==FMESI)
        {
            int size = (int)(buff[0+3]<<24|buff[1+3]<<16|buff[2+3]<<8|buff[3+3]);
            
            NSString* lstr1 = [NSString stringWithFormat:@"送信成功 [画像情報] [size:%d] [num:%d] [id:%d]", size, num, r];
            LOG(lstr1);
        }
        else if(kind==FMESR)
        {
            NSString* lstr2 = [NSString stringWithFormat:@"送信成功 [自動返信] [id:%d]", r];
            LOG(lstr2);
        }
        else if (kind==FTEXT)
        {
            NSString* lstr3 = [NSString stringWithFormat:@"送信成功 [テキスト] [str:%@] [id:%d]", [[NSMutableString alloc] initWithData:msg encoding:NSUTF8StringEncoding], r];
            LOG(lstr3);

        }
        else if(kind==FIMG)
        {
            NSString* lstr4 = [NSString stringWithFormat:@"送信成功 [画像] [No.%d] [id:%d]", num+1, r];
            LOG(lstr4);
        }
        preMesseageID = r;
    }
    
}

// 送信データにタグ情報を入れる
-(void)setTagMessage:(unsigned char *)buff kind:(unsigned char)kind Id:(int)_Id number:(unsigned char)num
{
    // Idは0-16383
    if(_Id>16383)_Id=16383;
    
    memcpy(&buff[3], buff, BUFFSIZE);
    
    buff[0]=(kind<<6)|(_Id>>8);
    buff[1]=(_Id & 255);
    buff[2]=num;
    
    
    //NSLog(@"[0]%x [1]%x [2]%x", (unsigned char)buff[0], (unsigned char)buff[1], (unsigned char)buff[2]);
}

// データから左端２ビットのkindを読み取る
-(unsigned char)getTagKind:(unsigned char *)data
{
    return (unsigned char)((data[0]&0xc0)>>6);
}
// データからIdを取り出す
-(unsigned int)getTagId:(unsigned char *)data
{
    return (unsigned int)(((data[0] & 0x3f)<<8)|data[1]);
}
// データからnumを取り出す
-(unsigned char)getTagNum:(unsigned char *)data
{
    return (unsigned char)data[2];
}


// メッセージの受信
// 受信スレッド
-(void)recieveThread
{
    unsigned char rcBuf[BUFFSIZEP];
    int rt=0;
    while (1)
    {
        memset(rcBuf, 0, sizeof(rcBuf));
        
        struct sockaddr_in from;
        int fromlen =(int)sizeof(from);
        
        int len = sizeof(rcBuf);
        
        rt = recvfrom(recieveSocket, rcBuf, (int)sizeof(rcBuf) , 0, (struct sockaddr*)&from, (socklen_t*)&fromlen);
        
        NSData *data = [NSData dataWithBytes:&rcBuf[3] length: BUFFSIZE];
        NSMutableString *buffstr = [[NSMutableString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        
        // ワイドバイトでの受信に対応させる（日本語など）char->NSData->NSstring
        if([self getTagKind:rcBuf]!=FMESR && imgRecvFlag==FALSE)
        {
            
            NSString* lstr1 = [NSString stringWithFormat:@"受信成功 [id:%d] [str:%@]", [self getTagId:rcBuf], buffstr];
            LOG(lstr1);
        }
        
        if(rt != len)
        {
            LOG(@"■受信失敗");
            //return;
            if(rt == -1)
            {
                
                LOG(@"ソケットの再作成");
                
                [self closeRecieve];
                
                [self createRecieve];
            }
        }
        
        else
        {
            if([self getTagKind:rcBuf]==FTEXT)
            {
                [self performSelectorOnMainThread:@selector(setrecvtext:) withObject:buffstr waitUntilDone:NO];
                
                NSString *_str=@"recv_OK";
                NSData* strData = [_str dataUsingEncoding:NSUTF8StringEncoding];
                
                // ワイドバイトでの送信に対応させる（日本語など）NSData->char->send
                unsigned char buff[BUFFSIZEP];
                memset(buff, 0, BUFFSIZEP);
                
                [strData getBytes:buff];
                
                [self setTagMessage:buff kind:FMESR Id:[self getTagId:rcBuf] number:0];
                
                int l = (int)sizeof(buff);
                
                int rt = sendto(sendSocket, buff, l+1, 0, (struct sockaddr*)(res->ai_addr), res->ai_addrlen);
                
                if(rt != l+1)
                {
                    LOG(@"■返信失敗 [テキスト]");
                    return;
                }
                
                NSString* lstr = [NSString stringWithFormat:@"返信成功 [テキスト] [id:%d]", [self getTagId:rcBuf]];
                LOG(lstr);

                
                recv_flag = TRUE;
            }
            
            else if([self getTagKind:rcBuf]==FIMG && imgRecvFlag)
            {
                
                NSString *_str=@"img_part_recv_OK";
                NSData* strData = [_str dataUsingEncoding:NSUTF8StringEncoding];
                
                // ワイドバイトでの送信に対応させる（日本語など）NSData->char->send
                unsigned char buff[BUFFSIZEP];
                memset(buff, 0, BUFFSIZEP);
                
                [strData getBytes:buff];
                
                [self setTagMessage:buff kind:FMESR Id:[self getTagId:rcBuf] number:0];
                
                int l = (int)sizeof(buff);
                
                int rt = sendto(sendSocket, buff, l+1, 0, (struct sockaddr*)(res->ai_addr), res->ai_addrlen);
                
                if(rt != l+1)
                {
                    LOG(@"■返信失敗 [画像]");
                    return;
                }
                

                
                static unsigned char *pdata;
                if(recv_img_num == 0)
                {
                    
                    pdata=malloc(imageSize); // 画像受信の１パーツ目の手前でデータサイズ分のメモリを確保
                    //memset(pdata, 0, imageSize);
                }
                
                if(recv_img_num != [self getTagNum:rcBuf])continue;
                
                int b=0;
                if(recv_img_num != (recv_img_num_max-1))
                {
                    memcpy(&pdata[(BUFFSIZE+b)*recv_img_num], &rcBuf[3], BUFFSIZE);
                    /*for(int m=0; m<BUFFSIZE; m++)
                    {
                        pdata[(BUFFSIZE+b) * recv_img_num + m] = rcBuf[3+m];
                        
                    }*/
                }
                else // 最後の１パーツならサイズはBUFFSIZEではない
                {
                    int llen = imageSize-BUFFSIZE*recv_img_num;
                    memcpy(&pdata[(BUFFSIZE+b)*recv_img_num], &rcBuf[3], llen);
                    /*for(int m=0; m<llen; m++)
                    {
                        pdata[(BUFFSIZE+b) * recv_img_num + m] = rcBuf[3+m];
                        
                    }*/
                }
                
                NSString* lstr = [NSString stringWithFormat:@"受信成功 [画像] [No.%d /%d] [id:%d]", [self getTagNum:rcBuf]+1, recv_img_num_max, [self getTagId:rcBuf]];
                LOG(lstr);

                
                recv_img_num++;
                
                if(recv_img_num==recv_img_num_max)// 受信終了　画像の復元完了させる
                {
                    NSData *imgdata = [NSData dataWithBytes:pdata length: imageSize];
                    recv_img = [UIImage imageWithData:imgdata];
                    
                    [self performSelectorOnMainThread:@selector(_setImage) withObject:nil waitUntilDone:YES];
                    
                    free(pdata);  // 確保したメモリを解放
                    recv_img_num=0;
                    imgRecvFlag=FALSE;
                    
                    LOG(@"画像受信完了");
                    
                    /*LOG(@"■■■■■");
                    NSMutableString *ls = [NSMutableString string];
                    for(int i=5990; i<6010;i++)
                    {
                        NSString* lstr = [NSString stringWithFormat:@"num:%5d buff:%3d", i, pdata[i]];
                        ls = [NSString stringWithFormat:@"%@\r\n%@", lstr, ls];
                    }
                    free(pdata);
                    LOG(ls);
                    LOG(@"■■■■■");*/
                    
                    
                }
                
            }
            
            else if([self getTagKind:rcBuf]==FMESI)
            {
                imgRecvFlag=TRUE;
                imageSize=(rcBuf[0+3]<<24 | rcBuf[1+3]<<16 | rcBuf[2+3]<<8 | rcBuf[3+3]);
                
                NSString* lstr = [NSString stringWithFormat:@"画像受信開始 [size:%d] [num:%d]", imageSize, (unsigned char)[self getTagNum:rcBuf]];
                LOG(lstr);
                
                recv_img_num_max=(unsigned char)[self getTagNum:rcBuf];
                NSString *_str=@"img_info_recv_OK";
                NSData* strData = [_str dataUsingEncoding:NSUTF8StringEncoding];
                
                // ワイドバイトでの送信に対応させる（日本語など）NSData->char->send
                unsigned char buff[BUFFSIZEP];
                memset(buff, 0, BUFFSIZEP);
                
                [strData getBytes:buff];
                
                [self setTagMessage:buff kind:FMESR Id:[self getTagId:rcBuf] number:0];
                
                int l = (int)sizeof(buff);
                
                int rt = sendto(sendSocket, buff, l+1, 0, (struct sockaddr*)(res->ai_addr), res->ai_addrlen);
                
                if(rt != l+1)
                {
                    LOG(@"■返信失敗 [画像情報]");
                    return;
                }
                
                NSString* lstr1 = [NSString stringWithFormat:@"返信成功 [画像情報] [id:%d]", [self getTagId:rcBuf]];
                LOG(lstr1);
                nextSendFlag = TRUE;
            }
            
            else if([self getTagKind:rcBuf]==FMESR)
            {
                if([self getTagId:rcBuf]==preMesseageID)
                {
                    
                    nextSendFlag=TRUE;
                    if([fifo count]!=0)[fifo removeObjectAtIndex:0];
                    
                    [self performSelectorOnMainThread:@selector(setfifonum:) withObject:[NSString stringWithFormat:@"%d", [fifo count]] waitUntilDone:NO];
                    
                    NSString* lstr1 = [NSString stringWithFormat:@"受信成功 [テキスト返信] [id:%d]", [self getTagId:rcBuf]];
                    LOG(lstr1);
                    //NSLog(@"[UDP]Success: 'recv_ok'[id:%d] fifo count:%d", [self getTagId:rcBuf], [fifo count]);
                }
            }
            
        }
        
    }
    
}
-(void)setfifonum:(NSString*)str
{
    fifoNum.text = str;
}
-(void)setrecvtext:(NSString*)str
{
    recvText.text = str;
}


-(void)_setImage
{
    [recvImg setImage:recv_img];
}

// 送信ソケット削除
-(void)closeSend
{
    int rt = close(sendSocket);
    if(rt==0)
    {
        LOG(@"送信ソケット削除成功");
        return;
    }
    LOG(@"■送信ソケット削除失敗");
}

// 受信ソケット削除
-(void)closeRecieve
{
    if(close(recieveSocket)==0)
    {
        LOG(@"受信ソケット削除成功");
        return;
    }
    LOG(@"■受信ソケット作成");
}

// カメラ起動
-(IBAction)camera:(id)sender
{

    if( [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera])
    {
        imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        imagePicker.cameraDevice=UIImagePickerControllerCameraDeviceFront;
        [self presentModalViewController:imagePicker animated:YES];
        
    }
}
//イメージピッカーのイメージ取得時に呼ばれる
- (void)imagePickerController:(UIImagePickerController*)picker
didFinishPickingMediaWithInfo:(NSDictionary*)info
{
    //イメージの指定
    UIImage* image=[info objectForKey:UIImagePickerControllerOriginalImage];
    [sendImg setImage:image];
    
    //ビューコントローラのビューを閉じる
    [[picker presentingViewController]dismissModalViewControllerAnimated:YES];
    
}


// 画像送信ボタン
-(IBAction)sendImg:(id)sender
{

    NSData *data = [[NSData alloc]initWithData:UIImageJPEGRepresentation(sendImg.image, 1.0)];
    //NSData *data = [[NSData alloc]initWithData:UIImagePNGRepresentation(sendImg.image)];
    
    
    // サイズが大きい場合は圧縮する
    int _size = [data length];
    
    if(_size > 255*BUFFSIZE)
    {
        data = [[NSData alloc]initWithData:UIImageJPEGRepresentation(sendImg.image, 0.8)];
        _size = [data length];
        LOG(@"画像が大きいので圧縮[0.8]");
    }
    
    if(_size > 255*BUFFSIZE)
    {
        data = [[NSData alloc]initWithData:UIImageJPEGRepresentation(sendImg.image, 0.6)];
        _size = [data length];
        LOG(@"画像が大きいので圧縮[0.6]");
    }

    if(_size > 255*BUFFSIZE)
    {
        data = [[NSData alloc]initWithData:UIImageJPEGRepresentation(sendImg.image, 0.4)];
        _size = [data length];
        LOG(@"画像が大きいので圧縮[0.4]");
    }
    
    if(_size > 255*BUFFSIZE)
    {
        data = [[NSData alloc]initWithData:UIImageJPEGRepresentation(sendImg.image, 0.2)];
        _size = [data length];
        LOG(@"画像が大きいので圧縮[0.2]");
    }
    
    if(_size > 255*BUFFSIZE)
    {
        data = [[NSData alloc]initWithData:UIImageJPEGRepresentation(sendImg.image, 0.1)];
        _size = [data length];
        LOG(@"画像が大きいので圧縮[0.1]");
    }
    
    if(_size > 255*BUFFSIZE)
    {
        LOG(@"■送信不可");
    }
    
    unsigned char* pdata = (unsigned char *)[data bytes];
    int size = [data length];
    
    NSString* lstr = [NSString stringWithFormat:@"image size:%d div:%d", size, (size/BUFFSIZE)+1];
    LOG(lstr);
    
    // 画像送信前に画像情報を送信する
    // IDをランダムに作成(最大で16383)
    int r = arc4random() % 16383;
    NSNumber * _num = [[NSNumber alloc]initWithFloat:(size/BUFFSIZE)+1];     // 分割数
    NSNumber * _id = [[NSNumber alloc]initWithFloat:r];         // ID
    NSNumber * _kind = [[NSNumber alloc]initWithFloat:FMESI];   // kind
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    unsigned char buf[BUFFSIZE];
    memset(buf, 0, BUFFSIZE);
    
    // size(int型)を無理矢理にchar[]へ1バイトずつ入れる。
    buf[0]=size>>24 & 0xff;
    buf[1]=size>>16 & 0xff;
    buf[2]=size>>8 & 0xff;
    buf[3]=size & 0xff;
    
    
    NSData *_data = [NSData dataWithBytes:buf length: BUFFSIZE];
    [arr addObject:_kind];
    [arr addObject:_id];
    [arr addObject:_num];
    [arr addObject:_data];
    [fifo addObject:arr];   // 送信データをキューに入れる
    fifoNum.text = [NSString stringWithFormat:@"%d", [fifo count]];
    
    int ren = (size/BUFFSIZE);
    
    unsigned char divImg[BUFFSIZE];
    for(int i=0;i<=ren;i++)
    {
        // 画像分割
        
        if(ren != i)memcpy(divImg, &pdata[BUFFSIZE*i], BUFFSIZE);
        else memcpy(divImg, &pdata[BUFFSIZE*i], (size-BUFFSIZE*i));
        
        // IDをランダムに作成(最大で16383)
        int r = arc4random() % 16383;
        
        NSNumber * _num = [[NSNumber alloc]initWithFloat:i];
        NSNumber * _id = [[NSNumber alloc]initWithFloat:r];
        NSNumber * _kind = [[NSNumber alloc]initWithFloat:FIMG];
        
        NSMutableArray *arr = [[NSMutableArray alloc] init];
        
        
        NSData *data = [NSData dataWithBytes:divImg length: BUFFSIZE];
        [arr addObject:_kind];
        [arr addObject:_id];
        [arr addObject:_num];
        [arr addObject:data];
        
        
        [fifo addObject:arr];   // 送信データをキューに入れる
        
        [NSThread sleepForTimeInterval:0.05];
        
    }
    fifoNum.text = [NSString stringWithFormat:@"%d", [fifo count]];
    
    timer = RESENDTIME;
    
    //NSLog(@"fifo count:%d", [fifo count]);
    /*
    LOG(@"画像受信完了");
    LOG(@"■■■■■");
    NSMutableString *ls = [NSMutableString string];
    for(int i=5990; i<6010;i++)
    {
        NSString* lstr = [NSString stringWithFormat:@"num:%5d buff:%3d", i, pdata[i]];
        ls = [NSString stringWithFormat:@"%@\r\n%@", lstr, ls];
    }
    LOG(ls);
    LOG(@"■■■■■");*/
    
}

// 送信画像保存
-(IBAction)saveSendImg:(id)sender
{
    
    UIImageWriteToSavedPhotosAlbum(sendImg.image, nil, nil, nil);
    UIAlertView *alert = [[UIAlertView alloc] init];
    alert.delegate = self;
    alert.title = @"保存しました";
    [alert addButtonWithTitle:@"閉じる"];
    [alert show];
    
}

// 受信画像保存
-(IBAction)saveRecvImg:(id)sender
{
    
    UIImageWriteToSavedPhotosAlbum(recvImg.image, nil, nil, nil);
    UIAlertView *alert = [[UIAlertView alloc] init];
    alert.delegate = self;
    alert.title = @"保存しました";
    [alert addButtonWithTitle:@"閉じる"];
    [alert show];
    
}


// 送信画像削除
-(IBAction)removeSendImg:(id)sender
{
    sendImg.image = nullImg;
}

// 受信画像削除
-(IBAction)removeRecvImg:(id)sender
{
    recvImg.image = nullImg;
}

-(IBAction)sendText:(id)sender
{
    // IDをランダムに作成(最大で16383)
    int r = arc4random() % 16383;
    
    NSNumber * _num = [[NSNumber alloc]initWithFloat:0];
    NSNumber * _id = [[NSNumber alloc]initWithFloat:r];
    NSNumber * _kind = [[NSNumber alloc]initWithFloat:FTEXT];
    NSData *mess = [sendText.text dataUsingEncoding:NSUTF8StringEncoding];
    NSMutableArray *arr = [[NSMutableArray alloc] init];
    
    [arr addObject:_kind];
    [arr addObject:_id];
    [arr addObject:_num];
    [arr addObject:mess];
    
    [fifo addObject:arr];   // 送信データをキューに入れる
    fifoNum.text = [NSString stringWithFormat:@"%d", [fifo count]];
    
    timer = RESENDTIME;
    
    return;
}

// テキスト削除
-(IBAction)clearText:(id)sender
{
    sendText.text = @"";
    recvText.text = @"";
}


-(void)LogOutput:(NSString*)str
{

    logText.text = [NSString stringWithFormat:@"%@\r\n%@", str, logText.text];
    
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    [self closeRecieve];
    [self closeSend];
    
}

-(bool)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation
{
    
    if ((toInterfaceOrientation == UIInterfaceOrientationLandscapeRight) ||
        (toInterfaceOrientation == UIInterfaceOrientationLandscapeLeft)) {
        return YES;
    }
    return NO;
}

@end
