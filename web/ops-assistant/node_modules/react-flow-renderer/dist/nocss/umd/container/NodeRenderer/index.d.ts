import React from 'react';
import { NodeMouseHandler, NodeTypesWrapped } from '../../types';
interface NodeRendererProps {
    nodeTypes: NodeTypesWrapped;
    selectNodesOnDrag: boolean;
    onNodeClick?: NodeMouseHandler;
    onNodeDoubleClick?: NodeMouseHandler;
    onNodeMouseEnter?: NodeMouseHandler;
    onNodeMouseMove?: NodeMouseHandler;
    onNodeMouseLeave?: NodeMouseHandler;
    onNodeContextMenu?: NodeMouseHandler;
    onlyRenderVisibleElements: boolean;
    noPanClassName: string;
    noDragClassName: string;
}
declare const _default: React.MemoExoticComponent<{
    (props: NodeRendererProps): JSX.Element;
    displayName: string;
}>;
export default _default;
