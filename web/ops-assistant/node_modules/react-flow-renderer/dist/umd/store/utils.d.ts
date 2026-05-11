import { GetState, SetState } from 'zustand';
import { Edge, EdgeSelectionChange, Node, NodeInternals, NodeSelectionChange, ReactFlowState, FitViewOptions } from '../types';
export declare function createNodeInternals(nodes: Node[], nodeInternals: NodeInternals): NodeInternals;
declare type InternalFitViewOptions = {
    initial?: boolean;
} & FitViewOptions;
export declare function fitView(get: GetState<ReactFlowState>, options?: InternalFitViewOptions): boolean;
export declare function handleControlledNodeSelectionChange(nodeChanges: NodeSelectionChange[], nodeInternals: NodeInternals): Map<string, Node<any>>;
export declare function handleControlledEdgeSelectionChange(edgeChanges: EdgeSelectionChange[], edges: Edge[]): Edge<any>[];
declare type UpdateNodesAndEdgesParams = {
    changedNodes: NodeSelectionChange[] | null;
    changedEdges: EdgeSelectionChange[] | null;
    get: GetState<ReactFlowState>;
    set: SetState<ReactFlowState>;
};
export declare function updateNodesAndEdgesSelections({ changedNodes, changedEdges, get, set }: UpdateNodesAndEdgesParams): void;
export {};
