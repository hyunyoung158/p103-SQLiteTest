//
//  ViewController.m
//  SQLiteTest
//
//  Created by SDT-1 on 2014. 1. 13..
//  Copyright (c) 2014년 SDT-1. All rights reserved.
//

#import "ViewController.h"
#import "DetailViewController.h"
#import "Movie.h"
#import <sqlite3.h>

@interface ViewController ()<UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate, UIAlertViewDelegate>

@property (weak, nonatomic) IBOutlet UITableView *table;
@end

@implementation ViewController {
    NSMutableArray *data;
    sqlite3 *db;
    NSInteger tmp;
}

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
    int ret = sqlite3_open([dbFilePath UTF8String], &db);
    NSAssert1(SQLITE_OK == ret, @"Error on opening Database : %s", sqlite3_errmsg(db));
    NSLog(@"Success on Opening Database");
    //테이블 생성
    const char *createSQL = "CREATE TABLE IF NOT EXISTS MOVIE (TITLE TEXT); CREATE TABLE IF NOT EXISTS ACTOR (NAME TEXT, rowid INT);";
    char *errorMsg;
    ret = sqlite3_exec(db, createSQL, NULL, NULL, &errorMsg);
    
    if (ret != SQLITE_OK) {
        [fm removeItemAtPath:dbFilePath error:nil];
        NSAssert1(SQLITE_OK == ret, @"Error on creating table: %s", errorMsg);
        NSLog(@"creating table with ret : %d", ret);
    }

}

// 새로운 데이터를 데이터베이스에 저장한다.
- (void)addData:(NSString *)input {
    NSLog(@"adding data :%@", input);
    
    //sqlite3_exec 로 실행하기
    NSString *sql = [NSString stringWithFormat:@"INSERT INTO MOVIE (TITLE) VALUES ('%@')", input];
    NSLog(@"sql : %@", sql);
    
    char *errMsg;
    int ret = sqlite3_exec(db, [sql UTF8String], NULL, nil, &errMsg);
    
    if (SQLITE_OK != ret) {
        NSLog(@"Error on Insert New data : %s", errMsg);
    }
    /*
    //바인딩 예제
    char *sql = "INSERT INTO MOVIE (TITLE) VALUES (?)";
    sqlite3_stmt *stmt;
    int ret = sqlite3_prepare_v2(db, sql, -1, &stmt, NULL);
    if (SQLITE_OK) {
        //? 에 대한 바인딩
        sqlite3_bind_text(stmt, 1, [input UTF8String], -1, NULL);
    }
    ret = sqlite3_step(stmt);
    if (SQLITE_DONE != ret) {
        NSLog(@"Error(%d) on adding data : %s", ret, sqlite3_errmsg(db));
    }
    
    sqlite3_finalize(stmt);
    */
    //이후 화면 갱신을 위해서 select를 호출
    [self resolveData];
}

//데이터베이스 닫기
- (void)closeDB {
    sqlite3_close(db);
}

//데이터베이스에서 정보를 가져온다.
- (void)resolveData {
    //기존 데이터 삭제
    [data removeAllObjects];
    
    //데이터베이스에서 사용할 쿼리 준비
    NSString *queryStr = @"SELECT rowid, title FROM MOVIE";
    sqlite3_stmt *stmt;
    int ret = sqlite3_prepare_v2(db, [queryStr UTF8String], -1, &stmt, NULL);
    
    NSAssert2(SQLITE_OK == ret, @"Error(%d) on resolving data : %s", ret, sqlite3_errmsg(db));
    
    //모든 행의 정보를 얻어온다.
    while (SQLITE_ROW == sqlite3_step(stmt)) {
        int rowID = sqlite3_column_int(stmt, 0);
        char *title = (char *)sqlite3_column_text(stmt, 1);
        
        //Movie 객체 생성, 데이터 세팅
        Movie *one = [[Movie alloc] init];
        one.rowID = rowID;
        one.title = [NSString stringWithCString:title encoding:NSUTF8StringEncoding];
        
        [data addObject:one];
    }
    
    sqlite3_finalize(stmt);
    
    //테이블 갱신
    [self.table reloadData];
}

//텍스트필드 리턴 저장
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if ([textField.text length] > 1) {
        [self addData:textField.text];
        [textField resignFirstResponder];
        textField.text = @"";
        
    }
    return YES;
}

//데이터 삭제
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (UITableViewCellEditingStyleDelete == editingStyle) {
        Movie *one = [data objectAtIndex:indexPath.row];
        NSString *sql = [NSString stringWithFormat:@"DELETE FROM MOVIE WHERE rowid=%d; DELETE FROM ACTOR WHERE rowid=%d", one.rowID, one.rowID];
        
        NSLog(@"sql : %@", sql);
        
        char *errorMsg;
        int ret = sqlite3_exec(db, [sql UTF8String], NULL, NULL, &errorMsg);
        
        if (SQLITE_OK != ret) {
            NSLog(@"Error(%d) on deleting data :%s", ret, errorMsg);
        }
        [self resolveData];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [data count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CELL_ID" forIndexPath:indexPath];
    
    //movie 데이터에서 타이틀 정보를 셀에 표시
    Movie *one = [data objectAtIndex:indexPath.row];
    cell.textLabel.text = one.title;
    return cell;
}

//셀 눌렀을때 알럿 뷰 띄우기..
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSLog(@"clicked %d", (int)indexPath.row);
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"제목" message:@"제목을 수정하시려면 입력 후 완료를 눌러주세요." delegate:self cancelButtonTitle:@"취소" otherButtonTitles:@"완료", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    //AlertView TextField 미리 채우기
    UITextField *movieTextField = [alert textFieldAtIndex:0];
    Movie *movie = [data objectAtIndex:indexPath.row];
    movieTextField.text = movie.title;
    [alert show];
}

//AlertView 내부 작동 로직
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.firstOtherButtonIndex == buttonIndex) {
        UITextField *movieName = [alertView textFieldAtIndex:0];
        NSLog(@"modified movieName : %@", movieName.text);
        //Update 로직 구현
        NSIndexPath *indexPath = [self.table indexPathForSelectedRow];
        Movie *movie = [data objectAtIndex:indexPath.row];
        NSString *sql = [NSString stringWithFormat:@"UPDATE MOVIE SET title='%@' WHERE rowid=%d", movieName.text, movie.rowID];
        NSLog(@"sql : %@", sql);
        
        char *errMsg;
        int ret = sqlite3_exec(db, [sql UTF8String], NULL, nil, &errMsg);
        
        if (SQLITE_OK != ret) {
            NSLog(@"Error on Update New data : %s", errMsg);
        }
        //데이터 갱신
        [self resolveData];
        
    }else {
        NSLog(@"취소");
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    DetailViewController *detailVC = segue.destinationViewController;
    //sender는 테이블의 셀!
    UITableViewCell *selectedCell = (UITableViewCell *)sender;
    //셀을 이용해서 indexPath를 얻어온다.
    NSIndexPath *selectedIndex = [self.table indexPathForCell:selectedCell];
    Movie *movie = [data objectAtIndex:selectedIndex.row];
    detailVC.cellRowId = movie.rowID;
}


- (void)viewDidLoad
{
    [super viewDidLoad];
    data = [NSMutableArray array];
    [self openDB];
}

- (void)viewWillAppear:(BOOL)animated {
    NSLog(@"viewWilAppear");
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES]; //네비게이션 바 감추기
    [self resolveData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO]; //네비게이션 바 보이기
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
