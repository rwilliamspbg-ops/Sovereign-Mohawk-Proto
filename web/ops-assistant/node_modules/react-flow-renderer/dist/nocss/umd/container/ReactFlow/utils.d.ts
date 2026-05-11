import { EdgeTypes, EdgeTypesWrapped, NodeTypes, NodeTypesWrapped } from '../../types';
import { CreateEdgeTypes } from '../EdgeRenderer/utils';
import { CreateNodeTypes } from '../NodeRenderer/utils';
export declare function useNodeOrEdgeTypes(nodeOrEdgeTypes: NodeTypes, createTypes: CreateNodeTypes): NodeTypesWrapped;
export declare function useNodeOrEdgeTypes(nodeOrEdgeTypes: EdgeTypes, createTypes: CreateEdgeTypes): EdgeTypesWrapped;
export declare function injectStyle(css: string): void;
