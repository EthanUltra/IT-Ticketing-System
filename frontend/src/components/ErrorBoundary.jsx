import React from 'react';

export default class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }

  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }

  componentDidCatch(error, info) {
    console.error('UI crash caught by ErrorBoundary:', error, info);
  }

  render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen flex items-center justify-center bg-surface-950 text-white p-6">
          <div className="max-w-md w-full rounded-xl border border-white/10 bg-surface-900 p-6">
            <h1 className="text-xl font-semibold mb-2">Something went wrong</h1>
            <p className="text-sm opacity-80 mb-4">
              The page crashed, but the app is still running.
            </p>
            <button
              className="px-4 py-2 rounded bg-orange-500 text-black font-medium"
              onClick={() => window.location.reload()}
            >
              Reload
            </button>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}