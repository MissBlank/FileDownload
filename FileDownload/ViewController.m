//
//  ViewController.m
//  FileDownload
//
//  Created by NERC on 2018/5/14.
//  Copyright © 2018年 GaoNing. All rights reserved.
//

#import "ViewController.h"
#import "TableViewCell.h"
#import "GNDownloadManager.h"
@interface ViewController ()<TableViewCellDelegate>

@property(nonatomic,strong)NSMutableArray * urls;

@end

@implementation ViewController

-(NSMutableArray *)urls{
    if (!_urls) {
        self.urls =[NSMutableArray array];
        for (int i =1 ; i<=10; i++) {
            [self.urls addObject:[NSString stringWithFormat:@"http://120.25.226.186:32812/resources/videos/minion_%02d.mp4",i]];
        }
    }
    return _urls;
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.urls.count;
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    return 100;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    TableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];


    cell.url =self.urls[indexPath.row];
    cell.delegate =self;
    
    
    return cell;
}


-(BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath{
    return YES;
}
-(UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    return UITableViewCellEditingStyleDelete;
    
}
-(void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        [[GNDownloadManager defaultInstance] removeWithURL:self.urls[indexPath.row]];
        [self.tableView reloadData];
    }
    
    
}

- (void)viewDidLoad {
    [super viewDidLoad];
    

}






- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
