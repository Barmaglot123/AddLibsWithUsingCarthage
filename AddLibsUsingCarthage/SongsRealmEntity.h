//
//  SongsRealmEntity.h
//  AddLibsUsingCarthage
//
//  Created by Денислям Ибраим on 12.04.17.
//  Copyright © 2017 Денислям Ибраим. All rights reserved.
//

#import <Realm/Realm.h>

@interface SongsRealmEntity : RLMObject

@property NSString * authorName;
@property NSString * songName;
@property NSString * songID;
@property NSString * version;

@end
