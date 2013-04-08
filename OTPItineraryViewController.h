//
//  OTPItineraryViewController.h
//  OpenTripPlanner
//
//  Created by asutula on 9/14/12.
//  Copyright (c) 2012 OpenPlans. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "RouteMe.h"
#import "Itinerary.h"
#import "OTPItineraryTableViewController.h"
#import "OTPItineraryMapViewController.h"
#import "OTPGeocodedTextField.h"
#import "ZUUIRevealController.h"
#import "OTPItineraryOverlayViewController.h"

@interface OTPItineraryViewController : ZUUIRevealController <ZUUIRevealControllerDelegate, UITableViewDataSource, UITableViewDelegate, RMMapViewDelegate, MFMailComposeViewControllerDelegate, OTPItineraryOverlayViewControllerDelegate>

// The itinerary to display
@property (nonatomic, strong) Itinerary *itinerary;

// The table view controller that displays leg information
@property (nonatomic, strong) OTPItineraryTableViewController *itineraryTableViewController;

// The map view controller that shows the trip on the map
@property (nonatomic, strong) OTPItineraryMapViewController *itineraryMapViewController;

// Set to the 'from' text from the directions input view so we can use it in this view controller
@property (nonatomic, strong) OTPGeocodedTextField *fromTextField;

// Set to the 'to' text from the directions input view so we can use it in this view controller
@property (nonatomic, strong) OTPGeocodedTextField *toTextField;

// Set according to whether the user showed their location on the directions input map
@property (nonatomic) BOOL mapShowedUserLocation;


// Called when the user taps the feedback button
- (void)presentFeedbackView;

// Called when the user dismisses this view controller with the done button
- (IBAction)done:(UIBarButtonItem *)sender;

@end
