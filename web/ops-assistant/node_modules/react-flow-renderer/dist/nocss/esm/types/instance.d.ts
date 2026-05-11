import { ViewportHelperFunctions, Viewport } from './general';
import { Node } from './nodes';
import { Edge } from './edges';
export declare type ReactFlowJsonObject<NodeData = any, EdgeData = any> = {
    nodes: Node<NodeData>[];
    edges: Edge<EdgeData>[];
    viewport: Viewport;
};
export declare namespace Instance {
    type GetNodes<NodeData> = () => Node<NodeData>[];
    type SetNodes<NodeData> = (payload: Node<NodeData>[] | ((nodes: Node<NodeData>[]) => Node<NodeData>[])) => void;
    type AddNodes<NodeData> = (payload: Node<NodeData>[] | Node<NodeData>) => void;
    type GetNode<NodeData> = (id: string) => Node<NodeData> | undefined;
    type GetEdges<EdgeData> = () => Edge<EdgeData>[];
    type SetEdges<EdgeData> = (payload: Edge<EdgeData>[] | ((edges: Edge<EdgeData>[]) => Edge<EdgeData>[])) => void;
    type GetEdge<EdgeData> = (id: string) => Edge<EdgeData> | undefined;
    type AddEdges<EdgeData> = (payload: Edge<EdgeData>[] | Edge<EdgeData>) => void;
    type ToObject<NodeData = any, EdgeData = any> = () => ReactFlowJsonObject<NodeData, EdgeData>;
}
export declare type ReactFlowInstance<NodeData = any, EdgeData = any> = {
    getNodes: Instance.GetNodes<NodeData>;
    setNodes: Instance.SetNodes<NodeData>;
    addNodes: Instance.AddNodes<NodeData>;
    getNode: Instance.GetNode<NodeData>;
    getEdges: Instance.GetEdges<EdgeData>;
    setEdges: Instance.SetEdges<EdgeData>;
    addEdges: Instance.AddEdges<EdgeData>;
    getEdge: Instance.GetEdge<EdgeData>;
    toObject: Instance.ToObject<NodeData, EdgeData>;
    viewportInitialized: boolean;
} & Omit<ViewportHelperFunctions, 'initialized'>;
