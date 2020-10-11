//
//  TabBarController.swift
//  LowRes NX Coder
//
//  Created by Timo Kloss on 25/01/2020.
//  Copyright © 2020 Inutilis Software. All rights reserved.
//

import UIKit

enum TabIndex: Int {
    case explorer
    case help
    case about
    case community
}

class TabBarController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        AppController.shared.tabBarController = self
        
        let explorerVC = self.storyboard!.instantiateViewController(withIdentifier: "ExplorerNav")

        let helpStoryboard = UIStoryboard(name: "Help", bundle: nil)
        let helpVC = helpStoryboard.instantiateInitialViewController()!
        
        let aboutVC = self.storyboard!.instantiateViewController(withIdentifier: "AboutNav")
        
        let communityVC = self.storyboard!.instantiateViewController(withIdentifier: "CommunityNav")
        
        explorerVC.tabBarItem = item(title: "My Programs", imageName: "programs")
        helpVC.tabBarItem = item(title: "Help", imageName: "help")
        aboutVC.tabBarItem = item(title: "About", imageName: "about")
        communityVC.tabBarItem = item(title: "Community", imageName: "community")
        
        self.viewControllers = [explorerVC, helpVC, aboutVC, communityVC]
        
        NotificationCenter.default.addObserver(self, selector: #selector(didAddProgram), name: NSNotification.Name(rawValue: "ProjectManagerDidAddProgram"), object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        AppController.shared.checkShowProgram()
    }
    
    func item(title: String, imageName: String) -> UITabBarItem {
        return UITabBarItem(title: title, image: UIImage(named: imageName), selectedImage: nil)
    }
    
    func dismissPresentedViewController(completion: @escaping () -> Void) {
        var topVC = self.selectedViewController
        if topVC is UINavigationController {
            topVC = (topVC as! UINavigationController).topViewController
        }
        if topVC?.presentedViewController != nil {
            topVC?.dismiss(animated: true, completion: completion)
        } else {
            completion()
        }
    }
    
    func showExplorer(animated: Bool, root: Bool) {
        self.selectedIndex = TabIndex.explorer.rawValue;
        let nav = self.selectedViewController as? UINavigationController
        if root {
            nav?.popToRootViewController(animated: animated)
        } else {
            /*
            if (![nav.topViewController isKindOfClass:[ExplorerViewController class]])
            {
                [nav popViewControllerAnimated:animated];
            }*/
        }
    }
    
    func showHelp(chapter: String) {
        self.selectedIndex = TabIndex.help.rawValue;
        let helpVC = self.selectedViewController as! HelpSplitViewController
        helpVC.showChapter(chapter)
    }
    
    @objc func didAddProgram() {
        if self.selectedIndex != 0 {
            self.selectedIndex = 0;
        }
    }
    
}