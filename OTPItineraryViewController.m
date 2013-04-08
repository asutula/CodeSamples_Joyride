//
//  OTPItineraryViewController.m
//  OpenTripPlanner
//
//  Created by asutula on 9/14/12.
//  Copyright (c) 2012 OpenPlans. All rights reserved.
//

#import "OTPAppDelegate.h"
#import "OTPItineraryViewController.h"
#import "Leg.h"
#import "ZUUIRevealController.h"
#import "OTPDirectionPanGestureRecognizer.h"
#import "OTPItineraryOverviewCell.h"
#import "OTPArrivalCell.h"
#import "OTPStepCell.h"
#import "OTPDistanceBasedLegCell.h"
#import "OTPStopBasedLegCell.h"
#import "OTPTransferCell.h"
#import "OTPUnitFormatter.h"
#import "OTPUnitData.h"

@interface OTPItineraryViewController () {
    // Boolean to keep track of whether the map is showing
    BOOL _mapShowing;
    
    // List of modes we want to display in terms of distance
    NSArray *_distanceBasedModes;
    
    // List of modes we want to display in terms of stops
    NSArray *_stopBasedModes;
    
    // List of modes we want to display in terms of transfer
    NSArray *_transferModes;
    
    // Dictionary of OTP modes to display strings
    NSDictionary *_modeDisplayStrings;
    
    // Dictionary of OTP modes to display images
    NSMutableDictionary *_modeIcons;
    
    // Dictionary of OTP modes to display icons for the map
    NSMutableDictionary *_popupModeIcons;
    
    // Dictionary of OTP relative directions to display strings
    NSDictionary *_relativeDirectionDisplayStrings;
    
    // Dictionary of OTP relative directions to display images
    NSMutableDictionary *_relativeDirectionIcons;
    
    // Dictionary of OTP absolute directions to display strings
    NSDictionary *_absoluteDirectionDisplayStrings;
    
    // An array to easily access the map shapes for each leg
    NSMutableArray *_shapesForLegs;
    
    // Keep track of the currently selected table row
    NSIndexPath *_selectedIndexPath;
    
    // A lookup of generated strings to display as primary instructions for each table cell
    NSMutableArray *_primaryInstructionStrings;
    
    // A lookup of generated strings to display as secondary instructions for each table cell
    NSMutableArray *_secondaryInstructionStrings;
    
    // A lookup of calculated images display for each table cell
    NSMutableArray *_cellIcons;
    
    // Our instructional overlay view controllers
    OTPItineraryOverlayViewController *_overlayViewController;
    OTPItineraryOverlayViewController *_mapOverlayViewController;
}

// A method to set all legs displayed on the map to the provided color
- (void)resetLegsWithColor:(UIColor *)color;

@end

@implementation OTPItineraryViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
	// Initialize our instance variables
    _mapShowing = NO;
    _shapesForLegs = [[NSMutableArray alloc] init];
    _primaryInstructionStrings = [[NSMutableArray alloc] init];
    _secondaryInstructionStrings = [[NSMutableArray alloc] init];
    _cellIcons = [[NSMutableArray alloc] init];
    _modeIcons = [[NSMutableDictionary alloc] init];
    _relativeDirectionIcons = [[NSMutableDictionary alloc] init];
    _popupModeIcons = [[NSMutableDictionary alloc] init];
    
    // Load a plist that contains display strings and image names for OTP data
    NSString *path = [[NSBundle mainBundle] pathForResource:@"otp" ofType: @"plist"];
    NSDictionary *otpDict = [NSDictionary dictionaryWithContentsOfFile:path];
    
    // Set our mode lookups and display strings referencing data loaded from the plist
    _distanceBasedModes = [[otpDict objectForKey:@"modes"] objectForKey:@"distanceBasedModes"];
    _stopBasedModes = [[otpDict objectForKey:@"modes"] objectForKey:@"stopBasedModes"];
    _transferModes = [[otpDict objectForKey:@"modes"] objectForKey:@"transferBasedModes"];
    _modeDisplayStrings = [otpDict objectForKey:@"modeDisplayStrings"];
    _relativeDirectionDisplayStrings = [otpDict objectForKey:@"relativeDirectionDisplayStrings"];
    _absoluteDirectionDisplayStrings = [otpDict objectForKey:@"absoluteDirectionDisplayStrings"];
    
    // Populate our image icon my mode looks with UIImage instances keyed by mode.
    // This way we only have to instantiate each image once.
    for (NSString* key in [otpDict objectForKey:@"modeIcons"]) {
        [_modeIcons setValue:[UIImage imageNamed:[[otpDict objectForKey:@"modeIcons"] objectForKey:key]] forKey:key];
    }
    for (NSString* key in [otpDict objectForKey:@"relativeDirectionIcons"]) {
        [_relativeDirectionIcons setValue:[UIImage imageNamed:[[otpDict objectForKey:@"relativeDirectionIcons"] objectForKey:key]] forKey:key];
    }    
    for (NSString* key in [otpDict objectForKey:@"popupModeIcons"]) {
        [_popupModeIcons setValue:[UIImage imageNamed:[[otpDict objectForKey:@"popupModeIcons"] objectForKey:key]] forKey:key];
    }

    // Iterate through each leg of the itinerary and populate our arrays of
    // display strings and images backing our table cells.
    // These are the strings and images actually used when returning
    // table cells.
    for (int i = 0; i < self.itinerary.legs.count; i++) {
        Leg *leg = [self.itinerary.legs objectAtIndex:i];
        
        if ([_distanceBasedModes containsObject:leg.mode]) {
            // distance based leg
            [_cellIcons insertObject:[_modeIcons objectForKey:leg.mode] atIndex:i];
            [_primaryInstructionStrings insertObject:[NSString stringWithFormat:@"%@ to %@", [_modeDisplayStrings objectForKey:leg.mode], leg.to.name.capitalizedString] atIndex:i];
            [_secondaryInstructionStrings insertObject:[NSNull null] atIndex:i];
        } else if ([_stopBasedModes containsObject:leg.mode]) {
            // stop based leg
            [_cellIcons insertObject:[_modeIcons objectForKey:leg.mode] atIndex:i];
            
            NSString *destination = leg.headsign.capitalizedString;
            if(destination == nil) {
                destination = leg.to.name.capitalizedString;
            }
            [_primaryInstructionStrings insertObject:[NSString stringWithFormat: @"Take the %@ %@ towards %@", leg.route, [_modeDisplayStrings objectForKey:leg.mode], destination] atIndex:i];
            [_secondaryInstructionStrings insertObject:[NSString stringWithFormat:@"Get off at %@", leg.to.name.capitalizedString] atIndex:i];
        } else if ([_transferModes containsObject:leg.mode]) {
            // transfer leg
            [_cellIcons insertObject:[_modeIcons objectForKey:leg.mode] atIndex:i];
            Leg *nextLeg = [self.itinerary.legs objectAtIndex:i+1];
            [_primaryInstructionStrings insertObject:[NSString stringWithFormat:@"Transfer to the %@", nextLeg.route.capitalizedString] atIndex:i];
            [_secondaryInstructionStrings insertObject:[NSNull null] atIndex:i];
        }
    }
    
    // Add display string for the arrival cell
    [_primaryInstructionStrings addObject:[NSString stringWithFormat:@"Arrive at %@", self.toTextField.text]];
    [_secondaryInstructionStrings addObject:[NSNull null]];
    
    // Instantiate the table view controller used to display trip legs
    // from the storyboard and set it up
    self.itineraryTableViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"ItineraryTableViewController"];
    self.itineraryTableViewController.tableView.dataSource = self;
    self.itineraryTableViewController.tableView.delegate = self;
    
    // Instantiate the map view controller used to display the trip
    // on a map from the storyboard and set it up
    self.itineraryMapViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"ItineraryMapViewController"];
    self.itineraryMapViewController.mapView.delegate = self;
    self.itineraryMapViewController.mapView.topPadding = 100;
    self.itineraryMapViewController.instructionLabel.hidden = YES;
    self.itineraryMapViewController.mapView.showsUserLocation = self.mapShowedUserLocation;
    
    // Make self, a ZUUIRevealController, the delegate for itself
    self.delegate = self;
    
    // Set up ZUUIRevealController controllers and properties
    self.frontViewController = self.itineraryTableViewController;
    self.rearViewController = self.itineraryMapViewController;
    self.frontViewShadowRadius = 5;
    self.rearViewRevealWidth = 260;
    self.maxRearViewRevealOverdraw = 0;
    self.toggleAnimationDuration = 0.1;
    // Add a custom gesture recognizer to the ZUUIRevealController front view controller
    // so we can get true horizontal movements and trigger the map reveal
    OTPDirectionPanGestureRecognizer *navigationBarPanGestureRecognizer = [[OTPDirectionPanGestureRecognizer alloc] initWithTarget:self action:@selector(revealGesture:)];
    navigationBarPanGestureRecognizer.direction = UISwipeGestureRecognizerDirectionRight;
    [self.frontViewController.view addGestureRecognizer:navigationBarPanGestureRecognizer];

    // If the user has never seen the instructional overlay, show it to them
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DID_SHOW_ITINERARY_OVERLAY"]) {
        _overlayViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"ItineraryOverlay"];
        _overlayViewController.delegate = self;
        _overlayViewController.view.alpha = 0;
        [self.navigationController.view addSubview:_overlayViewController.view];
        [UIView animateWithDuration:0.5 animations:^{
            _overlayViewController.view.alpha = 1;
        }];
    }
    
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    // Add the itineray data to the map and display the overview
    [self displayItinerary];
    [self displayItineraryOverview];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.itinerary.legs.count + 3;  // +3 for overview, final arrival info and feedback
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"h:mm a";
    
    UITableViewCell *cell = nil;
    
    UIView *selectedView = [[UIView alloc] init];
    selectedView.backgroundColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    
    // Overview cell
    if (indexPath.row == 0) {
        static NSString *CellIdentifier = @"OverviewCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        
        // Set from/to in itinerary overview cell
        ((OTPItineraryOverviewCell *)cell).fromLabel.text = self.fromTextField.text;
        ((OTPItineraryOverviewCell *)cell).toLabel.text = self.toTextField.text;
        cell.selectedBackgroundView = selectedView;
        return cell;
    }
    
    // Feedback cell
    if (indexPath.row == self.itinerary.legs.count + 2) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"FeedbackCell"];
        cell.selectedBackgroundView = selectedView;
        return cell;
    }
    
    // Pull our display strings from the arrays we populated in viewDidLoad
    NSString *primaryInstruction = [_primaryInstructionStrings objectAtIndex:indexPath.row-1];
    NSString *secondaryInstruction = [_secondaryInstructionStrings objectAtIndex:indexPath.row-1];
    
    // Arrival cell
    if (indexPath.row == self.itinerary.legs.count + 1) {
        
        static NSString *CellIdentifier = @"ArrivalCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
        
        ((OTPArrivalCell *)cell).destinationText.text = primaryInstruction;
        ((OTPArrivalCell *)cell).arrivalTime.text = [dateFormatter stringFromDate:self.itinerary.endTime];
    } else {
        // Get the trip leg corresponding to this row
        Leg *leg = [self.itinerary.legs objectAtIndex:indexPath.row-1];
        
        if ([_distanceBasedModes containsObject:leg.mode]) {
            // walk leg
            cell = [tableView dequeueReusableCellWithIdentifier:@"DistanceBasedLegCell"];
            
            ((OTPDistanceBasedLegCell *)cell).iconView.image = [_cellIcons objectAtIndex:indexPath.row-1];
            ((OTPDistanceBasedLegCell *)cell).instructionLabel.text = primaryInstruction;
            [((OTPDistanceBasedLegCell *)cell).instructionLabel sizeToFit];
            
            NSNumber *duration = [NSNumber numberWithFloat:roundf(leg.duration.floatValue/1000/60)];
            NSString *unitLabel = duration.intValue == 1 ? @"min" : @"min";
            ((OTPDistanceBasedLegCell *)cell).timeLabel.text = [NSString stringWithFormat:@"%i %@", duration.intValue, unitLabel];
            
            // Set up a unit formatter to properly display distance as a string
            OTPUnitFormatter *unitFormatter = [[OTPUnitFormatter alloc] init];
            unitFormatter.cutoffMultiplier = @3.28084F;
            unitFormatter.unitData = @[
            [OTPUnitData unitDataWithCutoff:@100 multiplier:@3.28084F roundingIncrement:@10 singularLabel:@"foot" pluralLabel:@"feet"],
            [OTPUnitData unitDataWithCutoff:@528 multiplier:@3.28084F roundingIncrement:@100 singularLabel:@"foot" pluralLabel:@"feet"],
            [OTPUnitData unitDataWithCutoff:@INT_MAX multiplier:@0.000621371F roundingIncrement:@0.1F singularLabel:@"mile" pluralLabel:@"miles"]
            ];
            
            ((OTPDistanceBasedLegCell *)cell).distanceLabel.text = [unitFormatter numberToString:leg.distance];
        } else if ([_stopBasedModes containsObject:leg.mode]) {
            // stop based leg
            cell = [tableView dequeueReusableCellWithIdentifier:@"StopBasedLegCell"];
            
            ((OTPStopBasedLegCell *)cell).iconView.image = [_cellIcons objectAtIndex:indexPath.row-1];
            
            ((OTPStopBasedLegCell *)cell).instructionLabel.text = primaryInstruction;
            [((OTPStopBasedLegCell *)cell).instructionLabel sizeToFit];
            
            ((OTPStopBasedLegCell *)cell).departureTimeLabel.text = [NSString stringWithFormat:@"%@", [dateFormatter stringFromDate:leg.startTime]];
            
            int intermediateStops = leg.intermediateStops.count + 1;
            NSString *stopUnitLabel = intermediateStops == 1 ? @"stop" : @"stops";
            ((OTPStopBasedLegCell *)cell).stopsLabel.text = [NSString stringWithFormat:@"%u %@", intermediateStops, stopUnitLabel];
            
            ((OTPStopBasedLegCell *)cell).toLabel.text = secondaryInstruction;
        } else if ([_transferModes containsObject:leg.mode]) {
            // transfer leg
            cell = [tableView dequeueReusableCellWithIdentifier:@"TransferBasedLegCell"];
            ((OTPTransferCell *)cell).iconView.image = [_cellIcons objectAtIndex:indexPath.row-1];
            
            ((OTPTransferCell *)cell).instructionLabel.text = primaryInstruction;
        }
    }
    cell.selectedBackgroundView = selectedView;
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Overview cell
    if (indexPath.row == 0) {
        return 60;
    }
    
    // Feedback cell
    if (indexPath.row == self.itinerary.legs.count + 2) {
        return 60;
    }
    
    NSString *primaryInstruction = [_primaryInstructionStrings objectAtIndex:indexPath.row-1];
    NSString *secondaryInstruction = [_secondaryInstructionStrings objectAtIndex:indexPath.row-1];
    
    // Arrival cell
    if (indexPath.row == self.itinerary.legs.count + 1) {
        float height = [primaryInstruction sizeWithFont:[UIFont boldSystemFontOfSize:13] constrainedToSize:CGSizeMake(193, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping].height;
        return MAX(60, 8 + height + 8);
    } else {
        Leg *leg = [self.itinerary.legs objectAtIndex:indexPath.row-1];
        if ([_distanceBasedModes containsObject:leg.mode]) {
            // Distance based leg
            float height = [primaryInstruction sizeWithFont:[UIFont boldSystemFontOfSize:13] constrainedToSize:CGSizeMake(191, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping].height;
            return MAX(60, 8 + height + 8);
        } else if ([_stopBasedModes containsObject:leg.mode]) {
            // Stop based leg
            float height1 = [primaryInstruction sizeWithFont:[UIFont boldSystemFontOfSize:13] constrainedToSize:CGSizeMake(191, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping].height;
            float height2 = [secondaryInstruction sizeWithFont:[UIFont systemFontOfSize:13] constrainedToSize:CGSizeMake(191, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping].height;
            return MAX(60, 8 + height1 + 10 + height2 + 8);
        } else if ([_transferModes containsObject:leg.mode]) {
            // Transfer leg
            float height = [primaryInstruction sizeWithFont:[UIFont boldSystemFontOfSize:13] constrainedToSize:CGSizeMake(250, MAXFLOAT) lineBreakMode:NSLineBreakByWordWrapping].height;
            return MAX(48, 8 + height + 8);
        }
    }
    return 60;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    _selectedIndexPath = indexPath;
    
    // Show the map if the selected cell is not the feedback cell
    if (!_mapShowing && !(indexPath.row == self.itinerary.legs.count + 2)) {
        [self revealToggle:self];
    }
    
    if (indexPath.row == 0) {
        // Overview cell selected
        [TestFlight passCheckpoint:@"ITINERARY_DISPLAY_OVERVIEW"];
        // Hide the instruction label with animation
        [UIView animateWithDuration:0.3 animations:^{
            float x = self.itineraryMapViewController.instructionLabel.center.x;
            float y = self.itineraryMapViewController.instructionLabel.center.y - self.itineraryMapViewController.instructionLabel.bounds.size.height;
            self.itineraryMapViewController.instructionLabel.center = CGPointMake(x, y);
        } completion:^(BOOL finished) {
            self.itineraryMapViewController.instructionLabel.hidden = YES;
        }];
        self.itineraryMapViewController.mapView.topPadding = 0;
        
        // Show all the trip legs with the same color
        [self resetLegsWithColor:[UIColor colorWithRed:0 green:0 blue:1 alpha:0.5]];
        // Show the trip overview
        [self displayItineraryOverview];
    } else if (indexPath.row == self.itinerary.legs.count + 1) {
        // Arrival cell (the last cell) selected
        [TestFlight passCheckpoint:@"ITINERARY_DISPLAY_ARRIVAL"];
        [self resetLegsWithColor:[UIColor colorWithRed:0 green:0 blue:1 alpha:0.5]];
        Leg *leg = [self.itinerary.legs lastObject];
        self.itineraryMapViewController.instructionLabel.text = [NSString stringWithFormat:@"Arrive at %@.", self.toTextField.text];
        [self.itineraryMapViewController.instructionLabel resizeHeightToFitText];
        if (self.itineraryMapViewController.instructionLabel.isHidden) {
            float x = self.itineraryMapViewController.instructionLabel.center.x;
            float y = self.itineraryMapViewController.instructionLabel.center.y - self.itineraryMapViewController.instructionLabel.bounds.size.height;
            self.itineraryMapViewController.instructionLabel.center = CGPointMake(x, y);
            self.itineraryMapViewController.instructionLabel.hidden = NO;
            // Show the instruction label
            [UIView animateWithDuration:0.3 animations:^{
                float x = self.itineraryMapViewController.instructionLabel.center.x;
                float y = self.itineraryMapViewController.instructionLabel.center.y + self.itineraryMapViewController.instructionLabel.bounds.size.height;
                self.itineraryMapViewController.instructionLabel.center = CGPointMake(x, y);
            }];
        }
        
        // Set the top padding on the map so zooming to show map features respects the instruction label
        self.itineraryMapViewController.mapView.topPadding = self.itineraryMapViewController.instructionLabel.bounds.size.height;
        
        // Zoom to the current (last) leg
        CLLocationCoordinate2D sw = CLLocationCoordinate2DMake(leg.to.lat.floatValue - 0.001, leg.to.lon.floatValue - 0.001);
        CLLocationCoordinate2D ne = CLLocationCoordinate2DMake(leg.to.lat.floatValue + 0.001, leg.to.lon.floatValue + 0.001);
        [self.itineraryMapViewController.mapView zoomWithLatitudeLongitudeBoundsSouthWest:sw northEast:ne animated:YES];
    } else if (indexPath.row == self.itinerary.legs.count + 2) {
        // Handle feedback cell
        // Nothing needed because we have a button in the cell that triggers the feedback display
    } else {
        // Show the selected trip leg on the map
        [TestFlight passCheckpoint:@"ITINERARY_DISPLAY_LEG"];
        
        // Reset all the legs to the same color and highlight the selected leg
        [self resetLegsWithColor:[UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:0.5]];
        RMShape *shape = [_shapesForLegs objectAtIndex:indexPath.row - 1];
        shape.lineColor = [UIColor colorWithRed:0 green:0 blue:1 alpha:0.5];
        
        Leg *leg = [self.itinerary.legs objectAtIndex:indexPath.row - 1];
        
        // Set the text of the instruction label
        if ([_distanceBasedModes containsObject:leg.mode]) {
            self.itineraryMapViewController.instructionLabel.text = [NSString stringWithFormat:@"%@ to %@.", [_modeDisplayStrings objectForKey:leg.mode], leg.to.name.capitalizedString];
        } else if ([_stopBasedModes containsObject:leg.mode]) {
            self.itineraryMapViewController.instructionLabel.text = [NSString stringWithFormat: @"Take the %@ %@ towards %@ and get off at %@.", leg.route.capitalizedString, ((NSString*)[_modeDisplayStrings objectForKey:leg.mode]).lowercaseString, leg.headsign.capitalizedString, leg.to.name.capitalizedString];
        } else if ([_transferModes containsObject:leg.mode]) {
            Leg *nextLeg = [self.itinerary.legs objectAtIndex:indexPath.row];
            self.itineraryMapViewController.instructionLabel.text = [NSString stringWithFormat:@"Transfer to the %@ %@.", nextLeg.route.capitalizedString, [_modeDisplayStrings objectForKey:nextLeg.mode]];
        }
        [self.itineraryMapViewController.instructionLabel resizeHeightToFitText];
        // Show the instruction label if it's hidden
        if (self.itineraryMapViewController.instructionLabel.isHidden) {
            float x = self.itineraryMapViewController.instructionLabel.center.x;
            float y = self.itineraryMapViewController.instructionLabel.center.y - self.itineraryMapViewController.instructionLabel.bounds.size.height;
            self.itineraryMapViewController.instructionLabel.center = CGPointMake(x, y);
            self.itineraryMapViewController.instructionLabel.hidden = NO;
            [UIView animateWithDuration:0.3 animations:^{
                float x = self.itineraryMapViewController.instructionLabel.center.x;
                float y = self.itineraryMapViewController.instructionLabel.center.y + self.itineraryMapViewController.instructionLabel.bounds.size.height;
                self.itineraryMapViewController.instructionLabel.center = CGPointMake(x, y);
            }];
        }
        
        self.itineraryMapViewController.mapView.topPadding = self.itineraryMapViewController.instructionLabel.bounds.size.height;
        
        // Cause the map to display the current leg
        [self displayLeg:leg];
    }
}

- (void)revealController:(ZUUIRevealController *)revealController didRevealRearViewController:(UIViewController *)rearViewController {
    // Make sure we don't do anything if the front view controller
    // is somehow swiped to the left (we don't support that)
    if (revealController.currentFrontViewPosition == FrontViewPositionLeft) return;
    
    _mapShowing = YES;
    
    // Show the instructional map overlay if the user has never seen it
    if (![[NSUserDefaults standardUserDefaults] boolForKey:@"DID_SHOW_ITINERARY_MAP_OVERLAY"]) {
        _mapOverlayViewController = [self.storyboard instantiateViewControllerWithIdentifier:@"ItineraryMapOverlay"];
        _mapOverlayViewController.delegate = self;
        _mapOverlayViewController.view.alpha = 0;
        [self.navigationController.view addSubview:_mapOverlayViewController.view];
        [UIView animateWithDuration:0.5 animations:^{
            _mapOverlayViewController.view.alpha = 1;
        }];
    }
    
    if (_selectedIndexPath == nil) {
        [TestFlight passCheckpoint:@"ITINERARY_SHOW_MAP_WITH_SWIPE"];
        _selectedIndexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    } else {
        [TestFlight passCheckpoint:@"ITINERARY_SHOW_MAP_FROM_TAP"];
    }
    // Make sure the selected table row is selected (logic elsewhere makes sure
    // _selectedIndexPath is the overview cell if the user didn't actually tap a cell
    [self.itineraryTableViewController.tableView selectRowAtIndexPath:_selectedIndexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
}

- (void)revealController:(ZUUIRevealController *)revealController didHideRearViewController:(UIViewController *)rearViewController {
    // Make sure we don't do anything if the front view controller
    // is somehow swiped to the left (we don't support that)
    if (revealController.currentFrontViewPosition != FrontViewPositionLeft) return;
    
    _mapShowing = NO;
    
    [TestFlight passCheckpoint:@"ITINERARY_HIDE_MAP_WITH_SWIPE"];
    
    [self.itineraryTableViewController.tableView deselectRowAtIndexPath:[self.itineraryTableViewController.tableView indexPathForSelectedRow] animated:YES];
}

- (void) displayItinerary {
    // Add the itineray to the map
    [self.itineraryMapViewController.mapView removeAllAnnotations];
    
    int legCounter = 0;
    for (Leg* leg in self.itinerary.legs) {
        if (legCounter == 0) {
            // Start marker
            RMAnnotation* startAnnotation = [RMAnnotation
                                             annotationWithMapView:self.itineraryMapViewController.mapView
                                             coordinate:CLLocationCoordinate2DMake(leg.from.lat.floatValue, leg.from.lon.floatValue)
                                             andTitle:nil];
            RMMarker *marker = [[RMMarker alloc] initWithUIImage:[UIImage imageNamed:@"marker-start.png"]];
            // Store the map marker in the userInfo of the annotation so it can be easily retrieved
            startAnnotation.userInfo = [[NSMutableDictionary alloc] init];
            [startAnnotation.userInfo setObject:marker forKey:@"layer"];
            [self.itineraryMapViewController.mapView addAnnotation:startAnnotation];
            
        }
        if (legCounter == self.itinerary.legs.count - 1) {
            // End marker
            RMAnnotation* endAnnotation = [RMAnnotation
                                           annotationWithMapView:self.itineraryMapViewController.mapView
                                           coordinate:CLLocationCoordinate2DMake(leg.to.lat.floatValue, leg.to.lon.floatValue)
                                           andTitle:leg.from.name];
            RMMarker *marker = [[RMMarker alloc] initWithUIImage:[UIImage imageNamed:@"marker-end.png"]];
            endAnnotation.userInfo = [[NSMutableDictionary alloc] init];
            [endAnnotation.userInfo setObject:marker forKey:@"layer"];
            [self.itineraryMapViewController.mapView addAnnotation:endAnnotation];
        }
        
        // Trip mode icon:
        RMAnnotation* modeAnnotation = [RMAnnotation
                                        annotationWithMapView:self.itineraryMapViewController.mapView
                                        coordinate:CLLocationCoordinate2DMake(leg.from.lat.floatValue, leg.from.lon.floatValue)
                                        andTitle:leg.mode];
        
        RMMarker *popupMarker = [[RMMarker alloc] initWithUIImage:[_popupModeIcons objectForKey:leg.mode]];
        modeAnnotation.userInfo = [[NSMutableDictionary alloc] init];
        [modeAnnotation.userInfo setObject:popupMarker forKey:@"layer"];
        [self.itineraryMapViewController.mapView addAnnotation:modeAnnotation];
        
        // Create the polyline we will add to the map for this leg
        RMShape *polyline = [[RMShape alloc] initWithView:self.itineraryMapViewController.mapView];
        polyline.lineColor = [UIColor colorWithRed:0 green:0 blue:1 alpha:0.5];
        polyline.lineWidth = 6;
        polyline.lineCap = kCALineCapRound;
        polyline.lineJoin = kCALineJoinRound;
        
        int counter = 0;
        
        for (CLLocation *loc in leg.decodedLegGeometry) {
            if (counter == 0) {
                [polyline moveToCoordinate:loc.coordinate];
            } else {
                [polyline addLineToCoordinate:loc.coordinate];
            }
            counter++;
        }
        
        // Add the polyline to an array so we can manipulate it and access it later
        [_shapesForLegs addObject:polyline];
        
        // Add the leg polyine to the map
        RMAnnotation *polylineAnnotation = [[RMAnnotation alloc] init];
        [polylineAnnotation setMapView:self.itineraryMapViewController.mapView];
        polylineAnnotation.coordinate = ((CLLocation*)[leg.decodedLegGeometry objectAtIndex:0]).coordinate;
        [polylineAnnotation setBoundingBoxFromLocations:leg.decodedLegGeometry];
        polylineAnnotation.userInfo = [[NSMutableDictionary alloc] init];
        [polylineAnnotation.userInfo setObject:polyline forKey:@"layer"];
        [self.itineraryMapViewController.mapView addAnnotation:polylineAnnotation];
        
        legCounter++;
    }
}

- (void)displayItineraryOverview {
    // Zoom the map to fit the entire trip
    [self.itineraryMapViewController.mapView zoomWithLatitudeLongitudeBoundsSouthWest:self.itinerary.bounds.swCorner northEast:self.itinerary.bounds.neCorner animated:YES];
}

- (void)displayLeg:(Leg *)leg {
    // Zoom in on a single leg
    [self.itineraryMapViewController.mapView zoomWithLatitudeLongitudeBoundsSouthWest:leg.bounds.swCorner northEast:leg.bounds.neCorner animated:YES];
}

- (RMMapLayer *)mapView:(RMMapView *)mapView layerForAnnotation:(RMAnnotation *)annotation {
    // Pull the map marker or shape out of the annotation user info
    RMMapLayer* l = [annotation.userInfo objectForKey:@"layer"];
    if ([l isKindOfClass:[RMShape class]]) {
        // If we get a shape, set the z index low so it shows up behind any map markers
        l.zPosition = -999.0;
    }
    return l;
}

- (void)mapView:(RMMapView *)mapView didUpdateUserLocation:(RMUserLocation *)userLocation {
    self.itineraryMapViewController.userLocation = userLocation;
    if (self.itineraryMapViewController.needsPanToUserLocation) {
        [self.itineraryMapViewController updateViewsForCurrentUserLocation];
    }
}

- (void)resetLegsWithColor:(UIColor *)color {
    for (RMShape *shape in _shapesForLegs) {
        shape.lineColor = color;
    }
}

- (void)userClosedOverlay:(UIView *)overlay {
    if (overlay.tag == 0) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DID_SHOW_ITINERARY_OVERLAY"];
    } else if (overlay.tag == 1) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"DID_SHOW_ITINERARY_MAP_OVERLAY"];
    }
}

- (void)presentFeedbackView {
    // Use Apple's email composer to allow the user to send email feedback
    if ([MFMailComposeViewController canSendMail]) {
        OTPAppDelegate *delegate = (OTPAppDelegate *)[[UIApplication sharedApplication] delegate];
        
        NSString *line = @"Please provide feedback above this line and leave everything below this line intact.";
        
        NSMutableArray *legStrings = [[NSMutableArray alloc] init];
        [legStrings addObject:self.itinerary.startTime];
        for (Leg *leg in self.itinerary.legs) {
            NSString *legString = [NSString stringWithFormat:@"%@(%@)", leg.mode, leg.route];
            [legStrings addObject:legString];
        }
        NSString *legsString = [legStrings componentsJoinedByString:@", "];
        
        NSString *body = [NSString stringWithFormat:@"\n\n\n\n%@\n\n%@\n\n%@", line, delegate.currentUrlString, legsString];
        
        MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
        controller.mailComposeDelegate = self;
        controller.navigationBar.tintColor = [UIColor colorWithRed:0.004 green:0.694 blue:0.831 alpha:1.000];
        [controller setToRecipients:@[@"joyride@openplans.org"]];
        [controller setSubject:@"Joyride Directions Feedback"];
        [controller setMessageBody:body isHTML:NO];
        if (controller) [self presentViewController:controller animated:YES completion:nil];
    } else {
        // If the device doesn't support email, alert the user
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unable to send feedback on this device" message:@"You can still send us feedback by emailing joyride@openplans.org." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles: nil];
        [alert show];
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
    if (result == MFMailComposeResultSent) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Thank You" message:@"Your feedback will be used to improve Joyride." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles: nil];
        [alert show];
    }
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)done:(UIBarButtonItem *)sender {
    [TestFlight passCheckpoint:@"ITINERARY_DONE"];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    _mapShowing = NO;
}

@end
