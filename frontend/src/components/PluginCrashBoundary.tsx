import { Component, ErrorInfo, ReactNode } from 'react';

interface PluginCrashBoundaryProps {
  pluginName: string;
  children: ReactNode;
}

interface PluginCrashBoundaryState {
  crashed: boolean;
}

class PluginCrashBoundary extends Component<PluginCrashBoundaryProps, PluginCrashBoundaryState> {
  public state: PluginCrashBoundaryState = { crashed: false };

  public componentDidCatch(error: Error, info: ErrorInfo) {
    this.setState({ crashed: true });
    void DeckyPluginLoader.quarantineCrashedPlugins([this.props.pluginName], error, info);
  }

  public componentDidUpdate(prevProps: PluginCrashBoundaryProps) {
    if (prevProps.pluginName !== this.props.pluginName && this.state.crashed) {
      this.setState({ crashed: false });
    }
  }

  public render(): ReactNode {
    if (this.state.crashed) return null;

    return this.props.children;
  }
}

export default PluginCrashBoundary;
