#import "SearchVC.h"
#import "CompassView.h"

#include "../../map/framework.hpp"
#include "../../search/result.hpp"

SearchVC * g_searchVC = nil;
SearchF g_searchF;
ShowRectF g_showRectF;
volatile int g_queryId = 0;

@interface Wrapper : NSObject
{ // HACK: ownership is taken by the "get" method caller
  search::Result * m_result;
}
- (id)initWithResult:(search::Result const &) res;
- (search::Result *)get;
@end

@implementation Wrapper

- (id)initWithResult:(search::Result const &) res
{
  if ((self = [super init]))
    m_result = new search::Result(res);
  return self;
}

- (void)dealloc
{
  delete m_result;
  [super dealloc];
}

- (search::Result const *)get
{
  return m_result;
}
@end

static void OnSearchResultCallback(search::Result const & res, int queryId)
{
  if (g_searchVC && queryId == g_queryId)
  {
    Wrapper * w = [[Wrapper alloc] initWithResult:res];
    [g_searchVC performSelectorOnMainThread:@selector(addResult:)
                                 withObject:w
                              waitUntilDone:NO];
    [w release];
  }
}

@implementation SearchVC

- (id)initWithSearchFunc:(SearchF)s andShowRectFunc:(ShowRectF)r
{
  if ((self = [super initWithNibName:nil bundle:nil]))
  {
    g_searchF = s;
    g_showRectF = r;
  }
  return self;
}

- (void)clearResults
{
  m_results.clear();
}

- (void)dealloc
{
  g_searchVC = nil;
  [self clearResults];
  [super dealloc];
}

- (void)loadView
{
  UITableView * tableView = [[[UITableView alloc] init] autorelease];
  tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  tableView.delegate = self;
  tableView.dataSource = self;
  self.view = tableView;
  self.title = @"Search";

  UISearchBar * searchBar = [[[UISearchBar alloc] init] autorelease];
  searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  self.navigationItem.titleView = searchBar;
  [searchBar sizeToFit];
  searchBar.delegate = self;
}

- (void)viewDidLoad
{
  g_searchVC = self;
}

- (void)viewDidUnload
{
  g_searchVC = nil;
}

- (void)searchBar:(UISearchBar *)sender textDidChange:(NSString *)searchText
{
  [self clearResults];
  [(UITableView *)self.view reloadData];
  ++g_queryId;

  if ([searchText length] > 0)
  {
    g_searchF([[searchText precomposedStringWithCompatibilityMapping] UTF8String],
              bind(&OnSearchResultCallback, _1, g_queryId));
  }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
  return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
  return m_results.size();
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
  UITableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"MyTableViewCell"];
  if (!cell)
    cell = [[[UITableViewCell alloc]
             initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"MyTableViewCell"]
            autorelease];
  
  if (indexPath.row < m_results.size())
  {
    cell.textLabel.text = [NSString stringWithUTF8String:m_results[indexPath.row].GetString()];
    float const h = tableView.rowHeight * 0.6;
    CompassView * v = [[[CompassView alloc] initWithFrame:
                      CGRectMake(0, 0, h, h)] autorelease];
    v.angle = (float)m_results[indexPath.row].GetDirectionFromCenter();
    cell.accessoryView = v;
  }
  else
  {
    cell.textLabel.text = @"";
    cell.accessoryView = nil;
  }
  return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
  if (indexPath.row < m_results.size())
  {
    if (m_results[indexPath.row].GetResultType() == search::Result::RESULT_FEATURE)
    {
      g_showRectF(m_results[indexPath.row].GetFeatureRect());
      [self.navigationController popViewControllerAnimated:YES];
    }
  }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
  return YES;  // All orientations are supported.
}

- (void)addResult:(id)result
{
  m_results.push_back(*[result get]);
  [(UITableView *)self.view reloadData];
}

@end
