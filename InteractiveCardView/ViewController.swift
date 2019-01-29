//
//  ViewController.swift
//  InteractiveCardView
//
//  Created by Oleksii on 1/25/19.
//  Copyright © 2019 Temabit. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDelegate {
    
    enum CardState {
        case expanded
        case collapsed
    }
    var isCardVisible = false
    var isAnimationCanceled = false
    var nextState: CardState {
        return isCardVisible ? .collapsed : .expanded
    }
    var cardViewController: CardViewController!
    var visualEffectView: UIVisualEffectView!
    let cardHeight: CGFloat = UIScreen.main.bounds.height - 100
    let cardHandleAreaHeight: CGFloat = 60
    let animationDuration = 0.8
    let openShutHeight: CGFloat = 100
    var runningAnimations = [UIViewPropertyAnimator]()
    var animationProgressWhenInterrupted: CGFloat = 0
    
    
    /*******************************************************/
    @IBOutlet weak var heightConstraint: NSLayoutConstraint!
    @IBOutlet weak var greenView: UIView!
    @IBOutlet weak var tableView: UITableView!
    let greenViewHeight: CGFloat = 250
    var greenViewCurrentHeight: CGFloat = 250
    var greenAnimations = [UIViewPropertyAnimator]()
    var greenProgressWhenInterrupted: CGFloat = 0
    var greenState: GreenState {
        return isGreenCollapsed ? .collapsed : .expanded
    }
    var isGreenCollapsed = false
    enum GreenState {
        case expanded
        case collapsed
    }
    
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        print("Begin")
        startAnimation()
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        switch tableView.panGestureRecognizer.state {
//        case .began:
//            print("Begin")
//            startAnimation()
        case .changed:
//            print("Changed")
            var fractionComplete = tableView.panGestureRecognizer.translation(in: view).y / greenViewHeight
            fractionComplete = isGreenCollapsed ? fractionComplete : -fractionComplete
            updateAnimation(fractionComplete: fractionComplete)
        case .ended:
            print("Ended")
            continueAnimation()
        default:
            break
        }
    }
    
    func beginAnimation() {
        if greenAnimations.isEmpty {
            let frameAnimator = UIViewPropertyAnimator(duration: 1.0, dampingRatio: 1) {
                switch self.greenState {
                case .expanded:
                    let frame = self.tableView.frame
                    self.tableView.frame = CGRect(x: frame.origin.x,
                                                  y: 70,
                                                  width: frame.width,
                                                  height: frame.height+200)
//                    self.tableView.frame.origin.y = 250
                case .collapsed:
                    let frame = self.tableView.frame
                    self.tableView.frame = CGRect(x: frame.origin.x,
                                                  y: 270,
                                                  width: frame.width,
                                                  height: frame.height-200)
//                    self.tableView.frame.origin.y = 50
                }
            }
            frameAnimator.addCompletion { _ in
                self.isGreenCollapsed = !self.isGreenCollapsed
                self.greenAnimations.removeAll()
            }
            frameAnimator.startAnimation()
            greenAnimations.append(frameAnimator)
        }
    }
    
    func startAnimation() {
        if greenAnimations.isEmpty {
            beginAnimation()
        }
        for animator in greenAnimations {
            animator.pauseAnimation()
            greenProgressWhenInterrupted = animator.fractionComplete
        }
    }
    
    func updateAnimation(fractionComplete: CGFloat) {
        for animator in greenAnimations {
            animator.fractionComplete = fractionComplete + greenProgressWhenInterrupted
        }
    }
    
    func continueAnimation() {
        for animator in greenAnimations {
            animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
        }
    }
    
    /*******************************************************/
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        
        visualEffectView = UIVisualEffectView(frame: view.frame)
        view.addSubview(visualEffectView)
        cardViewController = CardViewController(nibName: "CardViewController", bundle: nil)
        addChild(cardViewController)
        view.addSubview(cardViewController.view)
        cardViewController.view.frame = CGRect(x: 0,
                                               y: view.frame.height - cardHandleAreaHeight,
                                               width: view.bounds.width,
                                               height: cardHeight)
        visualEffectView.frame = cardViewController.view.frame
        cardViewController.view.clipsToBounds = true
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleCardTap(recognizer:)))
        let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handleCardPan(recognizer:)))
        cardViewController.handleArea.addGestureRecognizer(tapGestureRecognizer)
        cardViewController.handleArea.addGestureRecognizer(panGestureRecognizer)
        tapGestureRecognizer.delegate = self
        panGestureRecognizer.delegate = self
    }
    
    @objc func handleCardTap(recognizer: UITapGestureRecognizer) {
        if nextState == .expanded {
            self.visualEffectView.frame = self.view.frame
        }
        switch recognizer.state {
        case .ended:
            animateTransitionIfNeeded(state: nextState, duration: animationDuration)
        default:
            break
        }
    }
    
    @objc func handleCardPan(recognizer: UIPanGestureRecognizer) {
        let translationY = recognizer.translation(in: cardViewController.handleArea).y
        let velocityY = recognizer.velocity(in: cardViewController.handleArea).y
        switch recognizer.state {
        case .began:
            if nextState == .expanded {
                self.visualEffectView.frame = self.view.frame
            }
            startInteractiveTransition(state: nextState, duration: animationDuration)
        case .changed:
            var fractionComplete = translationY / cardHeight
            fractionComplete = isCardVisible ? fractionComplete : -fractionComplete
            updateInteractiveTransition(fractionComplete: fractionComplete)
        case .ended:
            print("TY: \(translationY) VY: \(velocityY) Visible: \(isCardVisible)")
            if translationY < openShutHeight && velocityY < 500 && isCardVisible {
                print("GOT TO TOP \(isCardVisible)")
                cancelInteractiveTransition()
            } else if translationY > -openShutHeight && velocityY > -500 && !isCardVisible {
                print("GO TO BOTTOM \(isCardVisible)")
                cancelInteractiveTransition()
            } else {
                continueInteractiveTransition()
            }
        default:
            break
        }
    }
    
    func animateTransitionIfNeeded(state: CardState, duration: TimeInterval) {
        if runningAnimations.isEmpty {
            // Frame Animator
            let frameAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1) {
                switch state {
                case .expanded:
                    self.cardViewController.view.frame.origin.y = self.view.frame.height - self.cardHeight
                case .collapsed:
                    self.cardViewController.view.frame.origin.y = self.view.frame.height - self.cardHandleAreaHeight
                }
            }
            frameAnimator.addCompletion { _ in
                if !self.isAnimationCanceled {
                    self.isCardVisible = !self.isCardVisible
                }
                self.isAnimationCanceled = false
                self.runningAnimations.removeAll()
            }
            frameAnimator.startAnimation()
            runningAnimations.append(frameAnimator)
            // CornerRaius Animator
            let cornerRadiusAnimator = UIViewPropertyAnimator(duration: duration, curve: .linear) {
                switch state {
                case .expanded:
                    self.cardViewController.view.layer.cornerRadius = 20
                    self.cardViewController.view.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
                case .collapsed:
                    self.cardViewController.view.layer.cornerRadius = 0
                }
            }
            cornerRadiusAnimator.startAnimation()
            runningAnimations.append(cornerRadiusAnimator)
            // Blur Animator
            let blurAnimator = UIViewPropertyAnimator(duration: duration, curve: .linear) {//dampingRatio: 1) {
                switch state {
                case .expanded:
                    self.visualEffectView.effect = UIBlurEffect(style: .dark)
                case .collapsed:
                    self.visualEffectView.effect = nil
                }
            }
            blurAnimator.startAnimation()
            blurAnimator.addCompletion {_ in
                if !self.isCardVisible {
                    self.visualEffectView.frame = self.cardViewController.view.frame
                }
            }
            runningAnimations.append(blurAnimator)
        }
    }
    
    func startInteractiveTransition(state: CardState, duration: TimeInterval) {
        if runningAnimations.isEmpty {
            animateTransitionIfNeeded(state: state, duration: duration)
        }
        for animator in runningAnimations {
            animator.pauseAnimation()
            animationProgressWhenInterrupted = animator.fractionComplete
        }
    }
    
    func updateInteractiveTransition(fractionComplete: CGFloat) {
        for animator in runningAnimations {
            animator.fractionComplete = fractionComplete + animationProgressWhenInterrupted
        }
    }
    
    func continueInteractiveTransition() {
        for animator in runningAnimations {
            animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
        }
    }
    
    func cancelInteractiveTransition(_ isOK: Bool = false) {
        isAnimationCanceled = true
        for animator in runningAnimations {
//            animator.pauseAnimation()
//            animator.isReversed = true
//            animator.startAnimation()
            if (animator.isRunning) {
                animator.isReversed = true
            } else {
                animator.isReversed = true
                animator.continueAnimation(withTimingParameters: nil, durationFactor: 0)
            }
        }
    }
}

extension ViewController: UIGestureRecognizerDelegate {
    
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        
        guard let panRecognizer = gestureRecognizer as? UIPanGestureRecognizer else { return true}
        let translationY = panRecognizer.translation(in: cardViewController.handleArea).y
        
        if translationY < 0 && isCardVisible {
            return false
        } else if translationY > 0 && !isCardVisible {
            return false
        } else {
            return true
        }
    }
  
}
