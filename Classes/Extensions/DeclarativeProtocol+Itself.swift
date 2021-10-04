extension DeclarativeProtocol {
	@discardableResult
    public func itself(_ itself: inout Self?) -> Self {
        itself = self
        return self
    }

	@discardableResult
    public func configure(_ closure: (Self) -> Void) -> Self {
        closure(self)
        return self
    }

	@discardableResult
	func bind<T>(_ state: State<T>, _ objectKeyPath: ReferenceWritableKeyPath<Self, T>) -> Self {
		state.listen { [weak self] in
			self?[keyPath: objectKeyPath] = $0
		}
		return self
	}

	@discardableResult
	func bind<T>(_ state: State<T>, _ closure: @escaping (Self, T) -> Void) -> Self {
		state.listen { [weak self] in
			guard let self = self else { return }
			closure(self, $0)
		}
		return self
	}
}
