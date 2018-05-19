//
//  ShareViewController.swift
//  LowRes NX Coder
//
//  Created by Timo Kloss on 1/5/18.
//  Copyright © 2018 Inutilis Software. All rights reserved.
//

import UIKit

class ShareViewController: LowResFormViewController {
    
    private weak var activity: ShareProgramActivity!
    private var explorerItem: ExplorerItem!
    private var headerSection: Section!
    private var loginRow: ButtonRow!
    private var logoutRow: LabelRow!
    private var titleRow: NameRow!
    private var descriptionRow: TextAreaRow!
    private var categorySection: SelectableSection<ListCheckRow<LCCPostCategory>>!
    private var userChangeObserver: Any?
    
    func setup(activity: ShareProgramActivity, programUrl: URL) {
        self.activity = activity
        self.explorerItem = ExplorerItem(fileUrl: programUrl)
    }
    
    override func viewDidLoad() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(onCancelTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Post", style: .done, target: self, action: #selector(onPostTapped))
        
        super.viewDidLoad()
        
        title = "Community"
        
        headerSection = Section(footer: "Post this program to your community profile! If we like it, we will feature it in the LowRes NX news.")
        var header = HeaderFooterView<ThumbHeaderView>(.nibFile(name: "ThumbHeaderView", bundle: nil))
        header.onSetupView = { [weak self] (view, _) in
            view.image = self?.explorerItem.image
        }
        headerSection.header = header
        form.append(headerSection)
        
        loginRow = ButtonRow()
        loginRow.title = "Log in / Register"
        loginRow.onCellSelection { [weak self] (cell, row) in
            guard let strongSelf = self else { return }
            let vc = CommLogInViewController.create()
            strongSelf.present(inNavigationViewController: vc)
        }
        
        logoutRow = LabelRow()
        logoutRow.cellSetup { (cell, row) in
            cell.selectionStyle = .default
            let label = UILabel()
            label.textColor = AppStyle.darkTintColor()
            label.text = "Log Out"
            label.sizeToFit()
            cell.accessoryView = label
        }
        logoutRow.onCellSelection { (cell, row) in
            CommunityModel.sharedInstance().logOut()
            row.deselect()
        }
        
        updateLogin()
        
        
        let titleSection = Section("Program Title")
        form.append(titleSection)
        
        titleRow = NameRow()
        titleRow.placeholder = "Title"
        titleRow.value = explorerItem.name
        titleRow.add(rule: RuleRequired())
        titleSection.append(titleRow)
        
        
        categorySection = SelectableSection("Category", selectionType: .singleSelection(enableDeselection: false))
        
        let gameRow = ListCheckRow<LCCPostCategory>()
        gameRow.title = "Game (or demo of game)"
        gameRow.selectableValue = .game
        categorySection.append(gameRow)
        
        let toolRow = ListCheckRow<LCCPostCategory>()
        toolRow.title = "Tool (editor, utility)"
        toolRow.selectableValue = .tool
        categorySection.append(toolRow)
        
        let demoRow = ListCheckRow<LCCPostCategory>()
        demoRow.title = "Demo (graphics/sound example)"
        demoRow.selectableValue = .demo
        categorySection.append(demoRow)

        let assetRow = ListCheckRow<LCCPostCategory>()
        assetRow.title = "Assets (sprites, tiles, fonts, music)"
        assetRow.selectableValue = .assets
        categorySection.append(assetRow)
        
        form.append(categorySection)
        
        
        let descriptionSection = Section("Description")
        form.append(descriptionSection)
        
        descriptionRow = TextAreaRow()
        descriptionRow.textAreaHeight = .dynamic(initialTextViewHeight: 100)
        descriptionRow.add(rule: RuleRequired())
        descriptionSection.append(descriptionRow)
        
        let guidelinesRow = ButtonRow()
        guidelinesRow.cellSetup { (cell, row) in
            cell.imageView!.image = #imageLiteral(resourceName: "about")
            cell.textLabel!.font = UIFont.systemFont(ofSize: 14)
        }
        guidelinesRow.title = "Community Guidelines"
        guidelinesRow.presentationMode = .show(controllerProvider: .storyBoard(storyboardId: "CommGuidelinesView", storyboardName: "Community", bundle: Bundle.main), onDismiss: nil)
        descriptionSection.append(guidelinesRow)
        
        // notifications
        
        userChangeObserver = NotificationCenter.default.addObserver(
            forName: NSNotification.Name.CurrentUserChange,
            object: nil,
            queue: .main)
        { [weak self] (notification) in
            self?.updateLogin()
        }
    }
    
    deinit {
        if let userChangeObserver = userChangeObserver {
            NotificationCenter.default.removeObserver(userChangeObserver)
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !explorerItem.hasImage {
            showAlert(withTitle: "No Program Icon", message: "Please capture a program icon before posting!") {
                self.presentingViewController?.dismiss(animated: true, completion: nil)
            }
        } else {
            var succeeded = false
            if let sourceCode = try? String(contentsOf: explorerItem.fileUrl, encoding: .utf8) {
                let coreWrapper = CoreWrapper()
                let error = coreWrapper.compileProgram(sourceCode: sourceCode)
                if error == nil {
                    succeeded = true
                }
            }
            if !succeeded {
                showAlert(withTitle: "Program Error", message: "Please fix the program before posting!") {
                    self.presentingViewController?.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
    
    private func updateLogin() {
        headerSection.removeAll()
        if let currentUser = CommunityModel.sharedInstance().currentUser {
            logoutRow.title = currentUser.username
            headerSection.append(logoutRow)
        } else {
            headerSection.append(loginRow)
        }
    }
    
    private func send() {
        guard
            let title = titleRow.value,
            let description = descriptionRow.value,
            let category = categorySection.selectedRow()?.value,
            let userId = CommunityModel.sharedInstance().currentUser.objectId
            else {
                assertionFailure()
                return
        }
        
        do {
            let imageUrl = explorerItem.imageUrl
            let programUrl = explorerItem.fileUrl
            
            let imageData = try Data(contentsOf: imageUrl)
            let programData = try Data(contentsOf: programUrl)
            
            isBusy = true
            CommunityModel.sharedInstance().uploadFile(withName: title + ".png", data: imageData) { (url, error) in
                if let serverImageUrl = url {
                    CommunityModel.sharedInstance().uploadFile(withName: title + ".nx", data: programData, completion: { (url, error) in
                        if let serverProgramUrl = url {
                            let post = LCCPost()
                            post.type = .program
                            post.title = title
                            post.detail = description
                            post.program = serverProgramUrl
                            post.image = serverImageUrl
                            post.category = category
                            
                            let params = post.dirtyDictionary()
                            let route = "/users/\(userId)/posts"
                            
                            CommunityModel.sharedInstance().sessionManager.post(route, parameters: params, progress: nil, success: { (task, response) in
                                if let responseDict = response as? [String: Any], let responsePost = responseDict["post"] as? [String: Any] {
                                    post.update(with: responsePost)
                                    post.resetDirty()
                                }
                                CommunityModel.sharedInstance().clearCache()
                                // self.project.postId = post.objectId;
                                
                                self.activity.activityDidFinish(true)
                                
                            }, failure: { (task, error) in
                                self.showSendError(error)
                            })
                        } else {
                            self.showSendError(error)
                        }
                    })
                } else {
                    self.showSendError(error)
                }
            }
        } catch {
            showSendError(error)
        }
    }
    
    private func showSendError(_ error: Error?) {
        isBusy = false
        CommunityModel.sharedInstance().handleAPIError(error, title: "Could Not Send Program", viewController: self)
    }
    
    @objc func onCancelTapped(_ sender: Any) {
        activity.activityDidFinish(false)
    }
    
    @objc func onPostTapped(_ sender: Any) {
        view.endEditing(true)
        
        guard CommunityModel.sharedInstance().currentUser != nil else {
            let vc = CommLogInViewController.create()!
            present(inNavigationViewController: vc)
            return
        }
        guard form.validate().isEmpty else {
            showAlert(withTitle: "Please fill out all fields!", message: nil, block: nil)
            return
        }
        guard categorySection.selectedRow() != nil else {
            showAlert(withTitle: "Please select a category!", message: nil, block: nil)
            return
        }
        
        send()
    }
    
}
