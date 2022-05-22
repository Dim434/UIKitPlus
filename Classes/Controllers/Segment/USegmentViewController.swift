//
//  Created by Антон Лобанов on 20.02.2021.
//

import UIKit

open class USegmentViewController: ViewController {
	public var currentViewController: USegmentContentViewController {
		self.viewControllers[self.pageCollectionView.currentIndex]
	}

	@UState public var contentState: USegmentContentState = .normal

    public private(set) var headerView: USegmentHeaderView?
	public private(set) var navigationBar: USegmentNavigationBarView
    public private(set) var viewControllers: [USegmentContentViewController] = []

    // MARK: - UI

    private lazy var verticalCollectionView = USegmentVerticalCollectionView(adapter: self)
    private lazy var pageCollectionView = USegmentPageCollectionView(adapter: self)

    // MARK: - Variables

    private var visibleCollaborativeScrollView: UIScrollView {
        return self.viewControllers[self.pageCollectionView.selectedIndex].segmentScrollView()
    }

    private var lastCollaborativeScrollView: UIScrollView?
	private var backGesture: UIPanGestureRecognizer?

    // MARK: - UIKit

    public init(
		headerView: USegmentHeaderView? = nil,
		navigationBar: USegmentNavigationBarView,
        viewControllers: [USegmentContentViewController]
    ) {
		self.headerView = headerView
		self.viewControllers = viewControllers
		self.navigationBar = navigationBar

		super.init(nibName: nil, bundle: nil)

		self.headerView?.delegate = self
		self.navigationBar.delegate = self
    }

    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    open override func viewDidLoad() {
        super.viewDidLoad()

		$contentState.listen { [weak self] in
			self?.segmentDidRefreshFinished()
		}

		self.viewControllers.forEach {
			$0.$contentState.listen { [weak self] in self?.segmentDidRefreshFinished() }

			$0.delegate = self

			if self.headerView != nil {
				$0.segmentScrollView().bounces = false
			}
		}

		self.view.addSubview(self.verticalCollectionView)

		NSLayoutConstraint.activate([
			self.verticalCollectionView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor),
			self.verticalCollectionView.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor),
			self.verticalCollectionView.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor),
			self.verticalCollectionView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
		])

		self.pageCollectionView.scrollToItem(at: 0, animated: false)

		DispatchQueue.main.async {
			UIView.setAnimationsEnabled(false)
			self.navigationBar.segment(didScroll: CGFloat(0))
			UIView.setAnimationsEnabled(true)
		}
    }

	open override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		guard self.backGesture == nil else { return }
		self.pageCollectionView.pageViewController.scrollView.map { scrollView in
			self.navigationController?.interactivePopGestureRecognizer.map {
				let targets = $0.value(forKey: "targets") as? NSMutableArray
				let panGesture = UIPanGestureRecognizer()
				panGesture.setValue(targets, forKey: "targets")
				panGesture.delegate = self
				scrollView.addGestureRecognizer(panGesture)
				self.backGesture = panGesture
			}
		}
	}

	open func segmentDidScroll() {}

	open func segmentDidRefreshFinished() {}

	public func addRefreshControl(_ completion: (UIScrollView) -> Void) {
		self.verticalCollectionView.addRefreshControl(completion)
	}
}

extension USegmentViewController: USegmentHeaderDelegate {
	public func segmentHeaderReload() {
		self.verticalCollectionView.reloadItem(at: IndexPath(item: 0, section: 0))
	}
}

extension USegmentViewController: USegmentNavigationBarDelegate
{
    func segmentNavigationBar(didSelect item: Int) {
        self.pageCollectionView.scrollToItem(at: item, animated: true)
        self.syncCollaborativeScrollIfNeeded()
    }
}

extension USegmentViewController: USegmentVerticalCollectionAdapter
{
    func segmentVerticalCollection(headerView collectionView: UICollectionView) -> UIView? {
		self.headerView
    }

    func segmentVerticalCollection(navigationBarView collectionView: UICollectionView) -> UIView? {
        guard self.viewControllers.count > 1 else { return nil }
        return self.navigationBar
    }

    func segmentVerticalCollection(pageCollectionView collectionView: UICollectionView) -> UIView {
        self.pageCollectionView
    }

    func segmentVerticalCollection(didScroll collectionView: UICollectionView) {
        self.syncVerticalScrollIfNeeded()
		self.segmentDidScroll()
    }
}

extension USegmentViewController: USegmentPageCollectionAdapter
{
    func segmentPageCollection(shouldShow index: Int) -> Bool {
        self.viewControllers[index].segmentShouldBeShowed()
    }

    func segmentPageCollectionViewControllers() -> [UIViewController] {
        self.viewControllers
    }

    func segmentPageCollectionWillBeginDragging() {
        self.viewControllers.forEach {
            $0.segmentScrollView().isScrollEnabled = false
        }
        self.syncCollaborativeScrollIfNeeded()
    }

    func segmentPageCollectionDidEndDragging() {
        self.viewControllers.forEach {
            $0.segmentScrollView().isScrollEnabled = true
        }
    }

    func segmentPageCollection(didScroll point: CGPoint) {
		self.navigationBar.segment(didScroll: (point.x / self.view.frame.width) - 1)
		self.segmentDidScroll()
    }
}

extension USegmentViewController: USegmentContentDelegate
{
    public func segmentContent(didScroll scrollView: UIScrollView) {
        self.syncVerticalScrollIfNeeded()
		self.segmentDidScroll()
    }
}

extension USegmentViewController: UIGestureRecognizerDelegate
{
	public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
		guard let panRecognizer = gestureRecognizer as? UIPanGestureRecognizer,
			  panRecognizer == self.backGesture
		else {
			return true
		}

		guard let gestureView = panRecognizer.view else { return true }

		let velocity = panRecognizer.velocity(in: gestureView).x

		guard velocity > 0 else { return false }

		guard let currentViewController = self.pageCollectionView.pageViewController.viewControllers?.first,
			  self.pageCollectionView.pageViewController.dataSource?.pageViewController(
				self.pageCollectionView.pageViewController,
				viewControllerBefore: currentViewController
			  ) == nil
		else {
			return false
		}

		return true
	}

	public func gestureRecognizer(
		_ gestureRecognizer: UIGestureRecognizer,
		shouldBeRequiredToFailBy otherGestureRecognizer: UIGestureRecognizer
	) -> Bool {
		gestureRecognizer == self.backGesture &&
		otherGestureRecognizer == self.pageCollectionView.pageViewController.scrollView?.panGestureRecognizer
	}
}

// MARK: - Private

private extension USegmentViewController
{
    func syncVerticalScrollIfNeeded() {
        guard self.headerView != nil else {
            self.verticalCollectionView.contentOffsetY = 0
            return
        }

        let ctx = (
            headerViewH: self.verticalCollectionView.sizeForHeader().height,
            verticalY: self.verticalCollectionView.contentOffsetY,
            lastVerticalY: self.verticalCollectionView.lastContentOffsetY,
            collaborativeY: self.visibleCollaborativeScrollView.contentOffset.y
        )

        let collaborativeY = ctx.verticalY >= ctx.headerViewH
            ? ctx.collaborativeY
            : ctx.collaborativeY > 0 && ctx.lastVerticalY >= ctx.headerViewH
            ? ctx.collaborativeY
            : 0

        let verticalY = collaborativeY > 0
            ? ctx.headerViewH
            : ctx.verticalY

		let contentOffsetY = max(0, collaborativeY)

        self.visibleCollaborativeScrollView.contentOffset.y = contentOffsetY
		self.visibleCollaborativeScrollView.bounces = contentOffsetY > 100
        self.verticalCollectionView.contentOffsetY = min(ctx.headerViewH, verticalY)
        self.verticalCollectionView.lastContentOffsetY = min(ctx.headerViewH, verticalY)
        self.lastCollaborativeScrollView = self.visibleCollaborativeScrollView
    }

    func syncCollaborativeScrollIfNeeded() {
        guard let collaborativeScrollView = self.lastCollaborativeScrollView,
              self.headerView != nil
        else {
            return
        }

        let ctx = (
            collaborativeY: collaborativeScrollView.contentOffset.y,
			navBarHeight: self.navigationBar.segmentHeight()
        )

        self.viewControllers
            .map { $0.segmentScrollView() }
            .filter { $0 != collaborativeScrollView }
            .forEach {
                if ctx.collaborativeY == 0 && $0.contentOffset.y > 0 { $0.contentOffset.y = 0 }
            }
    }
}
