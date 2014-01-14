//
//  DetailViewController.m
//  SQLiteTest
//
//  Created by SDT-1 on 2014. 1. 14..
//  Copyright (c) 2014년 SDT-1. All rights reserved.
//

#import "DetailViewController.h"
#import "Actor.h"
#import <sqlite3.h>

@interface DetailViewController ()<UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>
@property (weak, nonatomic) IBOutlet UITableView *table;

@end

@implementation DetailViewController {
    NSMutableArray *_data;
    sqlite3 *_db;
}

//+버튼 누를시 alertView
- (IBAction)addActor:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"배우 추가" message:@"추가할 배우의 이름을 적어주세요." delegate:self cancelButtonTitle:@"취소" otherButtonTitles:@"완료", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    
    [alert show];
}

//alertView 동작 로직
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.firstOtherButtonIndex == buttonIndex) {
        //데이터 추가.
        UITextField *nameTextField = [alertView textFieldAtIndex:0];
        [self addData:nameTextField.text];
    }
}
#pragma CRUD

//db 오픈 없으면 새로 만들기
- (void)openDB {
    //데이터베이스 파일 경로 구하기
    NSString *docPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSString *dbFilePath = [docPath stringByAppendingPathComponent:@"db.sqlite"];
    
    //데이터 베이스 파일 체크
    NSFileManager *fm = [NSFileManager defaultManager];
    BOOL existFile = [fm fileExistsAtPath:dbFilePath];
    
    //없으면 데이터 베이스 파일 생성.
    if (NO == existFile) {
        NSString *defaultDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"db.sqlite"];
        NSError *error;
        BOOL success = [fm copyItemAtPath:defaultDBPath toPath:dbFilePath error:&error];
        
        if (!success) {
            NSAssert1(0, @"Failed to create writable database file with message '%@'.", [error localizedDescription]);
        }
        
    }
    //데이터 베이스 오픈은 항상 해줘야.
    int ret = sqlite3_open([dbFilePath UTF8String], &_db);
    NSAssert1(SQLITE_OK == ret, @"Error on opening Database : %s", sqlite3_errmsg(_db));
    NSLog(@"Success on Opening Database");
    //테이블 생성
    const char *createSQL = "CREATE TABLE IF NOT EXISTS MOVIE (TITLE TEXT); CREATE TABLE IF NOT EXISTS ACTOR (NAME TEXT, rowid INT);";
    char *errorMsg;
    ret = sqlite3_exec(_db, createSQL, NULL, NULL, &errorMsg);
    
    if (ret != SQLITE_OK) {
        [fm removeItemAtPath:dbFilePath error:nil];
        NSAssert1(SQLITE_OK == ret, @"Error on creating table: %s", errorMsg);
        NSLog(@"creating table with ret : %d", ret);
    }
    
}

// 새로운 데이터를 데이터베이스에 저장한다. insertData
- (void)addData:(NSString *)input {
    NSLog(@"adding data :%@", input);
    
    //sqlite3_exec 로 실행하기
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO ACTOR (name,rowid) VALUES ('%@', %d)", input, (int)self.cellRowId];
    NSLog(@"sql : %@", sql);
    
    char *errMsg;
    int ret = sqlite3_exec(_db, [sql UTF8String], NULL, nil, &errMsg);
    
    if (SQLITE_OK != ret) {
        NSLog(@"Error on Insert New data : %s", errMsg);
    }
    //이후 화면 갱신을 위해서 select를 호출
    [self resolveData];
}

//데이터베이스에서 정보를 가져온다. resloveData
- (void)resolveData {
    //기존 데이터 삭제
    [_data removeAllObjects];
    
    //데이터베이스에서 사용할 쿼리 준비
    
    NSString *queryStr = [NSString stringWithFormat:@"SELECT rowid, name FROM ACTOR WHERE rowid=%d", (int)self.cellRowId];

    sqlite3_stmt *stmt;
    int ret = sqlite3_prepare_v2(_db, [queryStr UTF8String], -1, &stmt, NULL);
    
    NSAssert2(SQLITE_OK == ret, @"Error(%d) on resolving data : %s", ret, sqlite3_errmsg(_db));
    
    //모든 행의 정보를 얻어온다.
    while (SQLITE_ROW == sqlite3_step(stmt)) {
        int rowID = sqlite3_column_int(stmt, 0);
        char *name = (char *)sqlite3_column_text(stmt, 1);
        
        //Actor 객체 생성, 데이터 세팅
        Actor *actor = [[Actor alloc] init];
        actor.name = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
        actor.rowID = rowID;

        [_data addObject:actor];
    }
    
    sqlite3_finalize(stmt);
    
    //테이블 갱신
    [self.table reloadData];
}

//데이터 삭제
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (UITableViewCellEditingStyleDelete == editingStyle) {
        Actor *actor = [_data objectAtIndex:indexPath.row];
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM ACTOR WHERE name='%@'", actor.name];
        
        NSLog(@"sql : %@", sql);
        
        char *errorMsg;
        int ret = sqlite3_exec(_db, [sql UTF8String], NULL, NULL, &errorMsg);
        
        if (SQLITE_OK != ret) {
            NSLog(@"Error(%d) on deleting data :%s", ret, errorMsg);
        }
        [self resolveData];
    }
}



- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSLog(@"갯수 : %d", (int)[_data count]);
    return [_data count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"Cell draw");
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"DETAIL_ID" forIndexPath:indexPath];
    Actor *actor = [_data objectAtIndex:indexPath.row];
    cell.textLabel.text = actor.name;
    return cell;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self openDB];
    _data = [[NSMutableArray alloc] init];
	// Do any additional setup after loading the view.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self resolveData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
