//
//  SongsCollectionViewController.m
//  AddLibsUsingCarthage
//
//  Created by Денислям Ибраим on 11.04.17.
//  Copyright © 2017 Денислям Ибраим. All rights reserved.
//

#import "SongsCollectionViewController.h"
#import "Reachability.h"
#import "SongsRealmEntity.h"
#import <AFNetworking/AFNetworking.h>
#import "OneSongCollectionViewCell.h"
#import <Realm/Realm.h>

@interface SongsCollectionViewController ()
@property (strong, nonatomic) UIRefreshControl * refreshControl;
@property (strong, nonatomic) RLMResults * collectionViewDataArray;
@property (strong, nonatomic) RLMRealm * realm;
@property (strong, nonatomic) RLMNotificationToken * notificationToken;
@end

@implementation SongsCollectionViewController

static NSString * const reuseIdentifier = @"Cell";

- (void)viewDidLoad {
    [super viewDidLoad];
    self.realm = [RLMRealm defaultRealm];
    self.collectionViewDataArray = [SongsRealmEntity allObjects];
    
    
    __weak typeof(self) weakSelf = self;
    self.notificationToken = [[SongsRealmEntity allObjects] addNotificationBlock:^(RLMResults<SongsRealmEntity *> *results, RLMCollectionChange *changes, NSError *error) {
        if (error) {
            NSLog(@"Failed to open Realm on background worker: %@", error);
            return;
        }
        
        UICollectionView *collectionViewForUpdate = weakSelf.collectionView;

        if(changes.insertions.count > 0){
            NSIndexPath * indexPath = [NSIndexPath indexPathForRow:[changes.insertions[0] integerValue] inSection:0];
            [collectionViewForUpdate insertItemsAtIndexPaths:@[indexPath]];
        }
        if(changes.deletions.count > 0){
            NSIndexPath * indexPath = [NSIndexPath indexPathForRow:[changes.deletions[0] integerValue] inSection:0];
            [collectionViewForUpdate deleteItemsAtIndexPaths:@[indexPath]];
        }

    }];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.collectionView addSubview:self.refreshControl];
    [self.refreshControl addTarget:self action:@selector(loadData) forControlEvents:UIControlEventValueChanged];
    if(![self checkedInternetConnection] && [SongsRealmEntity allObjects].count == 0){
        [self showAlertView];
    }else{
        [self loadData];
 
    }
        
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.collectionViewDataArray.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    OneSongCollectionViewCell * cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    cell.layer.borderWidth = 1.0f;
    cell.layer.borderColor = [UIColor blackColor].CGColor;
    SongsRealmEntity * currentSong = [self.collectionViewDataArray objectAtIndex:indexPath.row];
    cell.SongNameLabel.text = currentSong.songName;
    cell.artistNameLabel.text = currentSong.authorName;
    
    return cell;

}
# pragma mark Load Data

-(void)loadData{

    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    [manager GET:@"http://tomcat.kilograpp.com/songs/api/songs" parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {


        if([SongsRealmEntity allObjects].count == 0){
            for (NSDictionary * dict in responseObject){
                [self addSongToEntity:dict];
            }
            [self.collectionView reloadData];
        }else{
        
            NSMutableArray * tempArray = [NSMutableArray new];
            NSMutableArray * inputData = [NSMutableArray new];
            
            for(SongsRealmEntity * currentSong in [SongsRealmEntity allObjects]){
                [tempArray addObject:[currentSong valueForKey:@"songID"]];
            }
            for(NSDictionary * dict in responseObject){
                [inputData addObject:[NSString  stringWithFormat:@"%@",[dict objectForKey:@"id"]]];
            }
            for (int i = 0; i< [responseObject count]; i++){
                
                if(![tempArray containsObject:[inputData objectAtIndex:i]]){
                    [self addSongToEntity:[responseObject objectAtIndex:i]];
                    NSLog(@"%@",[responseObject objectAtIndex:i]);
                 }
            }
            for (int i = 0; i < tempArray.count; i++){
            
                if(![inputData containsObject:[tempArray objectAtIndex:i]]){
                    NSPredicate *pred = [NSPredicate predicateWithFormat:@"songID = %@",[tempArray objectAtIndex:i]];
                    RLMResults<SongsRealmEntity *> *deleteSongWithPredicate = [SongsRealmEntity objectsWithPredicate:pred];
                    SongsRealmEntity * deleteSong  = [deleteSongWithPredicate objectAtIndex:0];
                    [self.realm beginWriteTransaction];
                    [self.realm deleteObject:deleteSong];
                    [self.realm commitWriteTransaction];
                }
            }

            
        }
        [self.refreshControl endRefreshing];

        
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
    
}



#pragma mark <UICollectionViewDelegate>

-(void)addSongToEntity:(NSDictionary *)song{
    [self.realm beginWriteTransaction];
    SongsRealmEntity * newSong = [[SongsRealmEntity alloc] init];
    newSong.songName   = [NSString stringWithFormat:@"%@",[song objectForKey:@"label"]];
    newSong.authorName = [NSString stringWithFormat:@"%@",[song objectForKey:@"author"]];
    newSong.songID     = [NSString stringWithFormat:@"%@",[song objectForKey:@"id"]];
    newSong.version    = [NSString stringWithFormat:@"%@",[song objectForKey:@"version"]];
    [self.realm addObject:newSong];
    [self.realm commitWriteTransaction];
  
}
-(void)showAlertView{
    UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"Внимание!" message:@"Отсутстует подключние к интернету. Локальная база пуста - нет данных для отображения." preferredStyle:UIAlertControllerStyleAlert];
    [alertView addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *action) {
        [self dismissViewControllerAnimated:YES completion:^{}];
    }]];
    [self presentViewController:alertView animated:YES completion:nil];
}
-(BOOL)checkedInternetConnection{

    Reachability *networkReachability = [Reachability reachabilityForInternetConnection];
    NetworkStatus networkStatus = [networkReachability currentReachabilityStatus];
    if (networkStatus == NotReachable) {
        NSLog(@"There IS NO internet connection");
        return NO;
    } else {
        NSLog(@"There IS internet connection");
        return YES;
    }
}

- (void)dealloc {
    [self.notificationToken stop];
}


@end
