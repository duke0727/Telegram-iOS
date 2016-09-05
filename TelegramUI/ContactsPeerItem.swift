import Foundation
import UIKit
import AsyncDisplayKit
import Postbox
import Display
import SwiftSignalKit
import TelegramCore

private let titleFont = Font.regular(17.0)
private let titleBoldFont = Font.medium(17.0)
private let statusFont = Font.regular(13.0)

class ContactsPeerItem: ListViewItem {
    let account: Account
    let peer: Peer
    let action: (Peer) -> Void
    let selectable: Bool = true
    
    let headerAccessoryItem: ListViewAccessoryItem?
    
    init(account: Account, peer: Peer, index: PeerNameIndex?, action: @escaping (Peer) -> Void) {
        self.account = account
        self.peer = peer
        self.action = action
        
        if let index = index {
            var letter: String = "#"
            if let user = peer as? TelegramUser {
                switch index {
                    case .firstNameFirst:
                        if let firstName = user.firstName, !firstName.isEmpty {
                            letter = firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased()
                        } else if let lastName = user.lastName, !lastName.isEmpty {
                            letter = lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()
                        }
                    case .lastNameFirst:
                        if let lastName = user.lastName, !lastName.isEmpty {
                            letter = lastName.substring(to: lastName.index(after: lastName.startIndex)).uppercased()
                        } else if let firstName = user.firstName, !firstName.isEmpty {
                            letter = firstName.substring(to: firstName.index(after: firstName.startIndex)).uppercased()
                        }
                }
            } else if let group = peer as? TelegramGroup {
                if !group.title.isEmpty {
                    letter = group.title.substring(to: group.title.index(after: group.title.startIndex)).uppercased()
                }
            } else if let channel = peer as? TelegramChannel {
                if !channel.title.isEmpty {
                    letter = channel.title.substring(to: channel.title.index(after: channel.title.startIndex)).uppercased()
                }
            }
            self.headerAccessoryItem = ContactsSectionHeaderAccessoryItem(sectionHeader: .letter(letter))
        } else {
            self.headerAccessoryItem = nil
        }
    }
    
    func nodeConfiguredForWidth(async: @escaping (@escaping () -> Void) -> Void, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, completion: @escaping (ListViewItemNode, @escaping () -> Void) -> Void) {
        async {
            let node = ContactsPeerItemNode()
            let makeLayout = node.asyncLayout()
            var first = false
            var last = false
            if let headerAccessoryItem = self.headerAccessoryItem {
                first = true
                if let previousItem = previousItem, let previousHeaderItem = previousItem.headerAccessoryItem, previousHeaderItem.isEqualToItem(headerAccessoryItem) {
                    first = false
                }
                
                last = true
                if let nextItem = nextItem, let nextHeaderItem = nextItem.headerAccessoryItem, nextHeaderItem.isEqualToItem(headerAccessoryItem) {
                    last = false
                }
            }
            let (nodeLayout, nodeApply) = makeLayout(self.account, self.peer, width, first, last)
            node.contentSize = nodeLayout.contentSize
            node.insets = nodeLayout.insets
            
            completion(node, {
                nodeApply()
            })
        }
    }
    
    func updateNode(async: @escaping (@escaping () -> Void) -> Void, node: ListViewItemNode, width: CGFloat, previousItem: ListViewItem?, nextItem: ListViewItem?, animation: ListViewItemUpdateAnimation, completion: @escaping (ListViewItemNodeLayout, @escaping () -> Void) -> Void) {
        if let node = node as? ContactsPeerItemNode {
            Queue.mainQueue().async {
                let layout = node.asyncLayout()
                async {
                    var first = false
                    var last = false
                    if let headerAccessoryItem = self.headerAccessoryItem {
                        first = true
                        if let previousItem = previousItem, let previousHeaderItem = previousItem.headerAccessoryItem, previousHeaderItem.isEqualToItem(headerAccessoryItem) {
                            first = false
                        }
                        
                        last = true
                        if let nextItem = nextItem, let nextHeaderItem = nextItem.headerAccessoryItem, nextHeaderItem.isEqualToItem(headerAccessoryItem) {
                            last = false
                        }
                    }
                    
                    let (nodeLayout, apply) = layout(self.account, self.peer, width, first, last)
                    Queue.mainQueue().async {
                        completion(nodeLayout, {
                            apply()
                        })
                    }
                }
            }
        }
    }
    
    func selected() {
        self.action(self.peer)
    }
}

private let separatorHeight = 1.0 / UIScreen.main.scale

class ContactsPeerItemNode: ListViewItemNode {
    private let separatorNode: ASDisplayNode
    private let highlightedBackgroundNode: ASDisplayNode
    
    private let avatarNode: ChatListAvatarNode
    private let titleNode: TextNode
    private let statusNode: TextNode
    
    private var account: Account?
    private var peer: Peer?
    private var avatarState: (Account, Peer)?
    
    required init() {
        self.separatorNode = ASDisplayNode()
        self.separatorNode.backgroundColor = UIColor(0xc8c7cc)
        self.separatorNode.isLayerBacked = true
        
        self.highlightedBackgroundNode = ASDisplayNode()
        self.highlightedBackgroundNode.backgroundColor = UIColor(0xd9d9d9)
        self.highlightedBackgroundNode.isLayerBacked = true
        
        self.avatarNode = ChatListAvatarNode(font: Font.regular(15.0))
        self.avatarNode.isLayerBacked = true
        
        self.titleNode = TextNode()
        self.statusNode = TextNode()
        
        super.init(layerBacked: false, dynamicBounce: false)
        
        self.addSubnode(self.separatorNode)
        self.addSubnode(self.avatarNode)
        self.addSubnode(self.titleNode)
        self.addSubnode(self.statusNode)
    }
    
    override func layoutForWidth(_ width: CGFloat, item: ListViewItem, previousItem: ListViewItem?, nextItem: ListViewItem?) {
        let makeLayout = self.asyncLayout()
        let (nodeLayout, nodeApply) = makeLayout(self.account, self.peer, width, previousItem != nil, nextItem != nil)
        self.contentSize = nodeLayout.contentSize
        self.insets = nodeLayout.insets
        nodeApply()
    }
    
    override func setHighlighted(_ highlighted: Bool, animated: Bool) {
        super.setHighlighted(highlighted, animated: animated)
        
        if highlighted {
            /*self.contentNode.displaysAsynchronously = false
            self.contentNode.backgroundColor = UIColor.clear
            self.contentNode.isOpaque = false*/
            
            self.highlightedBackgroundNode.alpha = 1.0
            if self.highlightedBackgroundNode.supernode == nil {
                self.insertSubnode(self.highlightedBackgroundNode, aboveSubnode: self.separatorNode)
            }
        } else {
            if self.highlightedBackgroundNode.supernode != nil {
                if animated {
                    self.highlightedBackgroundNode.layer.animateAlpha(from: self.highlightedBackgroundNode.alpha, to: 0.0, duration: 0.4, completion: { [weak self] completed in
                        if let strongSelf = self {
                            if completed {
                                strongSelf.highlightedBackgroundNode.removeFromSupernode()
                                /*strongSelf.contentNode.backgroundColor = UIColor.white
                                strongSelf.contentNode.isOpaque = true
                                strongSelf.contentNode.displaysAsynchronously = true*/
                            }
                        }
                        })
                    self.highlightedBackgroundNode.alpha = 0.0
                } else {
                    self.highlightedBackgroundNode.removeFromSupernode()
                    /*self.contentNode.backgroundColor = UIColor.white
                    self.contentNode.isOpaque = true
                    self.contentNode.displaysAsynchronously = true*/
                }
            }
        }
    }
    
    func asyncLayout() -> (_ account: Account?, _ peer: Peer?, _ width: CGFloat, _ first: Bool, _ last: Bool) -> (ListViewItemNodeLayout, () -> Void) {
        let makeTitleLayout = TextNode.asyncLayout(self.titleNode)
        let makeStatusLayout = TextNode.asyncLayout(self.statusNode)
        
        return { [weak self] account, peer, width, first, last in
            let leftInset: CGFloat = 65.0
            let rightInset: CGFloat = 10.0
            
            var titleAttributedString: NSAttributedString?
            var statusAttributedString: NSAttributedString?
            
            if let peer = peer {
                if let user = peer as? TelegramUser {
                    if let firstName = user.firstName, let lastName = user.lastName, !firstName.isEmpty, !lastName.isEmpty {
                        let string = NSMutableAttributedString()
                        string.append(NSAttributedString(string: firstName, font: titleFont, textColor: .black))
                        string.append(NSAttributedString(string: " ", font: titleFont, textColor: .black))
                        string.append(NSAttributedString(string: lastName, font: titleBoldFont, textColor: .black))
                        titleAttributedString = string
                    } else if let firstName = user.firstName, !firstName.isEmpty {
                        titleAttributedString = NSAttributedString(string: firstName, font: titleBoldFont, textColor: UIColor.black)
                    } else if let lastName = user.lastName, !lastName.isEmpty {
                        titleAttributedString = NSAttributedString(string: lastName, font: titleBoldFont, textColor: UIColor.black)
                    } else {
                        titleAttributedString = NSAttributedString(string: "Deleted User", font: titleBoldFont, textColor: UIColor(0xa6a6a6))
                    }
                    
                    statusAttributedString = NSAttributedString(string: "last seen recently", font: statusFont, textColor: UIColor(0xa6a6a6))
                } else if let group = peer as? TelegramGroup {
                    titleAttributedString = NSAttributedString(string: group.title, font: titleBoldFont, textColor: UIColor.black)
                } else if let channel = peer as? TelegramChannel {
                    titleAttributedString = NSAttributedString(string: channel.title, font: titleBoldFont, textColor: UIColor.black)
                }
            }
            
            let (titleLayout, titleApply) = makeTitleLayout(titleAttributedString, nil, 1, .end, CGSize(width: max(0.0, width - leftInset - rightInset), height: CGFloat.infinity), nil)
            
            let (statusLayout, statusApply) = makeStatusLayout(statusAttributedString, nil, 1, .end, CGSize(width: max(0.0, width - leftInset - rightInset), height: CGFloat.infinity), nil)
            
            let nodeLayout = ListViewItemNodeLayout(contentSize: CGSize(width: width, height: 48.0), insets: UIEdgeInsets(top: first ? 29.0 : 0.0, left: 0.0, bottom: 0.0, right: 0.0))
            
            return (nodeLayout, { [weak self] in
                if let strongSelf = self {
                    strongSelf.peer = peer
                    strongSelf.account = account
                    
                    if let peer = peer, let account = account, strongSelf.avatarState == nil || strongSelf.avatarState!.0 !== account || !strongSelf.avatarState!.1.isEqual(peer) {
                        strongSelf.avatarNode.setPeer(account: account, peer: peer)
                    }
                    
                    strongSelf.avatarNode.frame = CGRect(origin: CGPoint(x: 14.0, y: 4.0), size: CGSize(width: 40.0, height: 40.0))
                    
                    let _ = titleApply()
                    strongSelf.titleNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 4.0), size: titleLayout.size)
                    
                    let _ = statusApply()
                    strongSelf.statusNode.frame = CGRect(origin: CGPoint(x: leftInset, y: 25.0), size: statusLayout.size)
                    
                    let topHighlightInset: CGFloat = first ? 0.0 : separatorHeight
                    strongSelf.highlightedBackgroundNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -nodeLayout.insets.top - topHighlightInset), size: CGSize(width: nodeLayout.size.width, height: nodeLayout.size.height + topHighlightInset))
                    strongSelf.separatorNode.frame = CGRect(origin: CGPoint(x: 65.0, y: nodeLayout.contentSize.height - separatorHeight), size: CGSize(width: max(0.0, nodeLayout.size.width - 65.0), height: separatorHeight))
                    strongSelf.separatorNode.isHidden = last
                }
            })
        }
    }
    
    override func layoutHeaderAccessoryItemNode(_ accessoryItemNode: ListViewAccessoryItemNode) {
        let bounds = self.bounds
        accessoryItemNode.frame = CGRect(origin: CGPoint(x: 0.0, y: -29.0), size: CGSize(width: bounds.size.width, height: 29.0))
    }
}
