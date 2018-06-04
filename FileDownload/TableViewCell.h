//
//  TableViewCell.h
//  FileDownload
//
//  Created by NERC on 2018/5/14.
//  Copyright © 2018年 GaoNing. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DelayButton.h"

@class TableViewCell;
@protocol TableViewCellDelegate<NSObject>

-(void)cell:(TableViewCell *)cell didClickedBtn:(UIButton *)button;

@end


@interface TableViewCell : UITableViewCell


@property(nonatomic,strong)NSString * url;


@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UILabel *bytesLabel;
@property (weak, nonatomic) IBOutlet UILabel *speedLabel;
@property (weak, nonatomic) IBOutlet DelayButton *button;

@property(nonatomic,weak)id<TableViewCellDelegate>delegate;


@end
