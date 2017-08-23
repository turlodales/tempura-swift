//
//  ViewController.swift
//  KatanaExperiment
//
//  Created by Andrea De Angelis on 03/07/2017.
//  Copyright © 2017 Bending Spoons. All rights reserved.
//

import Foundation
import UIKit
import Katana

/// every ViewController will:
/*
 - connect to the store on willAppear and disconnect on didDisappear
 - update the viewModel when a new state is available
 - feed the view with the updated viewModel
 */

// TODO: with swift 4 we will be able to say that V should also be an uiview
open class ViewController<V: ModellableView, S: State>: UIViewController where V.VM.S == S {
  /// true if the viewController is connected to the store, false otherwise
  /// a connected viewController will receive all the updates from the store
  open var connected: Bool = true {
    didSet {
      guard self.connected != oldValue else { return }
      self.connected ? self.subscribeToStateUpdates() : self.unsubscribe?()
    }
  }
  
  /// the store the viewController will use to receive state updates
  public var store: AnyStore
  
  /// closure used to unsubscribe the viewController from state updates
  private var unsubscribe: StoreUnsubscribe?
  
  /// used to have the last viewModel available if we want to update it for local state changes
  public var viewModel: V.VM = V.VM() {
    didSet {
      // the viewModel is changed, update the View
      self.rootView.model = viewModel
    }
  }
  
  /// use the rootView to access the main view managed by this viewController
  open var rootView: V {
    return self.view as! V
  }
  
  /// used internally to load the specific main view managed by this view controller
  open override func loadView() {
    // TODO: this shitty force cast dance can be removed in swift 4
    let viewType = V.self as! UIView.Type
    let v = viewType.init(frame: .zero) as! V
    v.viewController = self
    v.setup()
    v.style()
    self.view = v as! UIView
  }
  
  /// the init of the view controller that will take the Store to perform the updates when the store changes
  public init(store: AnyStore, connected: Bool = true) {
    self.store = store
    self.connected = true
    super.init(nibName: nil, bundle: nil)
    self.setup()
  }
  
  // override to setup something after init
  open func setup() {}
  
  /// shortcut to the dispatch function
  open func dispatch(action: Action) {
    self.store.dispatch(action)
  }
  
  // we are not using storyboards so trigger a fatalError
  public required init?(coder aDecoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  /// subscribe to the state updates, the method storeDidChange will be called on every state change
  private func subscribeToStateUpdates() {
    // check if we are already subscribed
    guard self.unsubscribe == nil else { return }
    
    // subscribe
    let unsubscribe = self.store.addListener { [unowned self] in
      self.storeDidChange()
    }
    
    // trigger a state update
    self.storeDidChange()
    // save the unsubscribe closure
    self.unsubscribe = unsubscribe
  }
  
  /// this method is called every time the store trigger a state update
  private func storeDidChange() {
    guard let newState = self.store.anyState as? S else { fatalError("wrong state type") }
    self.update(with: newState)
  }
  
  /// handle the state update, create a new updated viewModel and feed the view with that
  open func update(with state: S) {
    // update the view model using the new state available
    // note that the updated method should take into account the local state that should remain untouched
    self.viewModel = V.VM(state: state)
  }
  
  /// before the view will appear on screen, update the view and subscribe for state updates
  open override func viewWillAppear(_ animated: Bool) {
    if self.connected {
      self.subscribeToStateUpdates()
    }
    super.viewWillAppear(animated)
  }
  
  /// after the view disapper from screen, we stop listening for state updates
  open override func viewWillDisappear(_ animated: Bool) {
    if self.connected {
      self.unsubscribe?()
    }
    super.viewWillDisappear(animated)
  }
  
  open override func viewDidLoad() {
    super.viewDidLoad()
    self.setupInteraction()
  }
  
  /// ask to setup the interaction with the managed view
  open func setupInteraction() {}
  
  // not necessary?
  deinit {
    self.unsubscribe?()
  }
}
