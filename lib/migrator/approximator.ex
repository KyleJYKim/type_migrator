defmodule Migrator.Approximator do

  #key_types = {:atom, :pid, :port, :reference, :float, :integer, :bitstring, :binary, :tuple, :open_map, :fun, :list}

  def promote(field_org) do
    promoter = fn left_org, promoter_fun ->
      promoter_fun = &promoter_fun.(&1, promoter_fun)
      case left_org do
        # {:union, {left_u, right_u}} -> {:union, {left_u |> promoter_fun.(), right_u |> promoter_fun.()}}

        #{:tuple, _} -> {:tuple, left_org}
        #{:open_map, _} -> {:open_map, left_org}
        :empty_list -> {:list, [left_org]}
        {:non_empty_list, _} -> {:list, [left_org]}
        #{:fun, _} -> {:fun_top, [left_org]}
        {:gradual, :fun} -> {:fun, [left_org]}
        {:interval, _} -> {:integer, [left_org]}
        {:atom, singleton} -> {:atom, [singleton]}
        {:atom_req, _} -> {:atom, [left_org]}

        _ -> {left_org, [left_org]}
      end
    end
    field_org |> Enum.map(fn {left_f, right_f} -> {left_f |> promoter.(promoter), right_f} end)
  end

  def map(fields) do
    merging = fn {list1, field_m}, merging_fun ->
        merging_fun = &merging_fun.(&1, merging_fun)
        case list1 do
          [] -> {field_m, []}
          [field_l1 | rest_l1] ->
            {field_m_new, rest_l1_new} = {rest_l1, field_m} |> merging_fun.()
            if field_m_new == nil do
              {nil, [field_l1 | rest_l1_new]}
            else
              {{left_l1, left_l1_org}, right_l1} = field_l1
              {{left_m, left_m_org}, right_m} = field_m_new
              # If K^s' in L_1
              key_type_found_in_list? = left_l1 == left_m
              # If atom^s' in L_1
              atom_type_found_in_list? = left_l1 == :atom
              # If K union s is a subtype of K union s'
              {left_m_org_new, merging_org_type_subtype?} = if key_type_found_in_list? do
                {left_l1, {left_m_org, left_l1_org}} |> IO.inspect(label: "BEFORE UNIFYING SUBTYPES") |> unify_subtypes() |> IO.inspect(label: "AFTER UNIFYING SUBTYPES")
              else
                {left_m_org, false} |> IO.inspect(label: "AFTER NOT UNIFYING SUBTYPES")
              end

              key_type_found_in_list? |> IO.inspect(label: "KEY_TYPE_FOUND_IN_LIST?")
              atom_type_found_in_list? |> IO.inspect(label: "ATOM_TYPE_FOUND_IN_LIST?")
              merging_org_type_subtype? |> IO.inspect(label: "MERGING_ORG_TYPE_SUBTYPE?")

              cond do
                key_type_found_in_list? and !atom_type_found_in_list? and merging_org_type_subtype? ->
                  {nil, [field_l1 | rest_l1_new]}
                key_type_found_in_list? and !atom_type_found_in_list? and !merging_org_type_subtype? ->
                  {{{left_m, left_m_org_new}, (right_l1 ++ right_m) |> Enum.uniq()}, rest_l1_new}
                key_type_found_in_list? and atom_type_found_in_list? and merging_org_type_subtype? ->
                  {nil, [field_l1 | rest_l1_new]}
                key_type_found_in_list? and atom_type_found_in_list? and !merging_org_type_subtype? ->
                  case left_m_org_new |> IO.inspect(label: "ATOM ORG JUDGE") do
                    [atom_req: _] -> {field_m_new, [field_l1 | rest_l1_new]} |> IO.inspect(label: "ATOM ORG JUDGE RESULT1")
                    [:atom] -> {field_m_new, [field_l1 | rest_l1_new]} |> IO.inspect(label: "ATOM ORG JUDGE RESULT2")
                    _ -> {{{left_m, left_m_org_new}, (right_l1 ++ right_m) |> Enum.uniq()}, rest_l1_new} |> IO.inspect(label: "ATOM ORG JUDGE RESULT3")
                  end
                !key_type_found_in_list? ->
                  {field_m_new, [field_l1 | rest_l1_new]}
              end
            end
        end
      end

    checking_if_set = fn fields -> fields |> Enum.map(fn {left_f, right_f} ->
          right_f_new = right_f |> Enum.reduce({nil}, fn type, acc ->
              case acc do
                {nil} -> type
                {:union, _} -> {:union, {type, acc}}
                acc_t -> {:union, {type, acc_t}}
              end
            end)
          right_f_new = case left_f do
            {:atom, [atom_req: _]} -> right_f_new
            _ -> {:if_set, right_f_new}
          end
          {left_f, right_f_new}
        end)
      end

    merging_total = fn fields ->
        fields |> Enum.reduce([], fn field, list1 ->
            {field_new, list_l1_new} = {list1, field} |> merging.(merging)
            if field_new == nil do
              list_l1_new
            else
              [field_new | list_l1_new]
            end
          end) |> checking_if_set.()
      end

    removing_extra_information = fn fields ->
        fields |> Enum.map(fn {{key_type, org_type}, right_f} ->
          case org_type do
            [atom_req: singleton] -> {singleton, right_f}
            _ -> {key_type, right_f}
          end
        end)
      end

    fields |> merging_total.() |> removing_extra_information.()
  end

  #key_types = {:atom, :pid, :port, :reference, :float, :integer, :bitstring, :binary, :tuple, :open_map, :fun, :list}
  defp unify_subtypes({:atom, {left_m_org, left_l1_org}}) do
    if left_m_org == left_l1_org do
      {left_l1_org, true}
    else
      {{m_org_new, l1_org_new}, subtype_new?} = left_m_org |> Enum.reduce({{[], left_l1_org}, true}, fn lmo, {{acc_m_org, acc_l1_org}, acc_subtype?} ->
        acc_l1_org |> Enum.reduce({{acc_m_org, []}, acc_subtype?}, fn ll1o, {{acc_m_org_new, acc_l1_org_new}, acc_subtype_new?} ->
          case {lmo, ll1o} do
            {_, :atom} -> {{[], [nil]}, true}
            {:atom, _} -> {{[:atom], []}, false}
            {{:atom_req, sgt1}, {:atom_req, sgt2}} ->
              if sgt1 == sgt2 do
                {{[], acc_l1_org_new ++ [ll1o]}, acc_subtype_new? and true}
              else
                {{[lmo], []}, acc_subtype_new? and false}
              end
            _ ->
              if lmo == ll1o do
                {{acc_m_org_new, acc_l1_org_new ++ [ll1o]}, acc_subtype_new? and true}
              else
                {{acc_m_org_new ++ [lmo], acc_l1_org_new ++ [ll1o]}, acc_subtype_new? and false}
              end
          end
        end)
      end)
      org_type_new = m_org_new ++ l1_org_new
      {org_type_new, subtype_new?}
    end
  end
  defp unify_subtypes({:integer, {left_m_org, left_l1_org}}) do
    comparing_intervals = fn {{n1_m, n2_m}, {n1_l1, n2_l1}} ->
        cond do
          {n1_m, n2_m} == {n1_l1, n2_l1} ->
            {[{:interval, {n1_l1, n2_l1}}], true}
          [n1_m, n2_m, n1_l1, n2_l1] |> Enum.find_value(false, fn n -> n == :infty end) ->
            case {n1_m, n2_m, n1_l1, n2_l1} do
              {_, _, :infty, -1} -> if n1_m < 0 and n2_m < 0, do: {[{:interval, {n1_l1, n2_l1}}], true}, else: {[{:interval, {n1_m, n2_m}}, {:interval, {n1_l1, n2_l1}}], false}
              {1, :infty, 0, :infty} -> {[{:interval, {n1_l1, n2_l1}}], true}
              {0, :infty, 1, :infty} -> {[{:interval, {n1_m, n2_m}}], false}
              {_, _, 0, :infty} -> if n1_m > -1 and n2_m > -1, do: {[{:interval, {n1_l1, n2_l1}}], true}, else: {[{:interval, {n1_m, n2_m}}, {:interval, {n1_l1, n2_l1}}], false}
              {_, _, 1, :infty} -> if n1_m > 0 and n2_m > 0, do: {[{:interval, {n1_l1, n2_l1}}], true}, else: {[{:interval, {n1_m, n2_m}}, {:interval, {n1_l1, n2_l1}}], false}
              {:infty, -1, _, _} -> if n1_l1 < 0 and n2_l1 < 0, do: {[{:interval, {n1_m, n2_m}}], false}, else: {[{:interval, {n1_m, n2_m}}, {:interval, {n1_l1, n2_l1}}], false}
              {1, :infty, _, _} -> if n1_l1 > 0 and n2_l1 > 0, do: {[{:interval, {n1_m, n2_m}}], false}, else: {[{:interval, {n1_m, n2_m}}, {:interval, {n1_l1, n2_l1}}], false}
              {0, :infty, _, _} -> if n1_l1 > -1 and n2_l1 > -1, do: {[{:interval, {n1_m, n2_m}}], false}, else: {[{:interval, {n1_m, n2_m}}, {:interval, {n1_l1, n2_l1}}], false}
            end
          Range.disjoint?(n1_m..n2_m, n1_l1..n2_l1) ->
            cond do
              n2_m + 1 == n1_l1 -> {[{:interval, {n1_m, n2_l1}}], false}
              n2_l1 + 1 == n1_m -> {[{:interval, {n1_l1, n2_m}}], false}
              true -> {[{:interval, {n1_m, n2_m}}, {:interval, {n1_l1, n2_l1}}], false}
            end
          n1_m..n2_m |> Enum.to_list() |> Enum.reduce(true, fn n, acc -> acc and Enum.member?(n1_l1..n2_l1, n) end) ->
            {[{:interval, {n1_l1, n2_l1}}], true}
          true ->
            cond do
              n1_m <= n1_l1 and n2_m <= n2_l1 -> {[{:interval, {n1_m, n2_l1}}], false}
              n1_m <= n1_l1 and n2_m >= n2_l1 -> {[{:interval, {n1_m, n2_m}}], false}
              n1_m >= n1_l1 and n2_m <= n2_l1 -> {[{:interval, {n1_l1, n2_l1}}], false}
              n1_m >= n1_l1 and n2_m >= n2_l1 -> {[{:interval, {n1_l1, n2_m}}], false}
            end
        end
      end

    {{m_org_new, l1_org_new}, subtype_new?} = left_m_org |> Enum.reduce({{[], left_l1_org}, true}, fn lmo, {{acc_m_org, acc_l1_org}, acc_subtype?} ->
        acc_l1_org |> Enum.reduce({{acc_m_org, []}, acc_subtype?}, fn ll1o, {{acc_m_org_new, acc_l1_org_new}, acc_subtype_new?} ->
          case {lmo, ll1o} do
            # {:integer, :integer} -> {:integer, false} # keep both right-hand type?
            {_, :integer} -> {{[], [nil]}, true}
            {:integer, _} -> {{[:integer], []}, false}
            {{:interval, {n1_m, n2_m}}, {:interval, {n1_l1, n2_l1}}} ->
              {org_type, subtype?} = {{n1_m, n2_m}, {n1_l1, n2_l1}} |> comparing_intervals.()
              case org_type do
                [org_type_m, org_type_l1] -> {{acc_m_org_new ++ [org_type_m], acc_l1_org_new ++ [org_type_l1]}, acc_subtype_new? and subtype?}
                [org_type_union] -> {{acc_m_org_new ++ [org_type_union], acc_l1_org_new}, acc_subtype_new? and subtype?}
              end
          end
        end)
      end)
    org_type_new = m_org_new ++ l1_org_new
    {org_type_new, subtype_new?}
  end
  defp unify_subtypes({:list, {left_m_org, left_l1_org}}) do
    comparing_non_empty_lists = fn {t_m, t_l1}, comparing_fun ->
        comparing_fun = &comparing_fun.(&1, comparing_fun)
        case {t_m, t_l1} |> IO.inspect(label: "T_INSPECT") do
          _ when t_m == t_l1 -> {t_l1, true}
          {{:union, {t_m_l, t_m_r}}, {:union, {t_l1_l, t_l1_r}}} ->
            {t_m_l_unified, t_m_l_subtype?} = {t_m_l, t_l1_l} |> comparing_fun.()
            {t_m_l_unified, t_m_l_subtype?} = if t_m_l_subtype?, do: {nil, true}, else: {t_m_l_unified, t_l1_r} |> comparing_fun.()
            {t_m_r_unified, t_m_r_subtype?} = {t_m_r, t_l1_l} |> comparing_fun.()
            {t_m_r_unified, t_m_r_subtype?} = if t_m_r_subtype?, do: {nil, true}, else: {t_m_r_unified, t_l1_r} |> comparing_fun.()
            if t_m_l_subtype? and t_m_r_subtype? do
              {nil, true}
            else
              {{:union, {t_m_l_unified, t_m_r_unified}}, false}
            end
          {_, {:union, {t_l1_l, t_l1_r}}} ->
            {t_m_unified, t_m_subtype?} = {t_m, t_l1_l} |> comparing_fun.()
            {t_m_unified, t_m_subtype?} = if t_m_subtype?, do: {nil, true}, else: {t_m_unified, t_l1_r} |> comparing_fun.()
            if t_m_subtype? do
              {nil, true}
            else
              {t_m_unified, false}
            end
          {{:union, {t_m_l, t_m_r}}, _} ->
            {t_m_unified, t_m_subtype?} = {t_m, t_m_l} |> comparing_fun.()
            {t_m_unified, t_m_subtype?} = if t_m_subtype?, do: {nil, true}, else: {t_m_unified, t_m_r} |> comparing_fun.()
            if t_m_subtype? do
              {nil, true}
            else
              {t_m_unified, false}
            end
          {_, :term} -> {:term, true}
          {{:interval, _}, {:interval, _}} -> {:integer, {[t_m], [t_l1]}} |> unify_subtypes() # need to change it to :union form...
          {{:non_empty_list, _}, {:non_empty_list, _}} -> {:list, {[t_m], [t_l1]}} |> unify_subtypes()
          # {{:tuple, _}, {:tuple, _}} -> unify_subtypes({:map, {t_m, t_l1}})
          # {{:map, _}, {:map, _}} -> unify_subtypes({:map, {t_m, t_l1}})
          _ -> {{t_m, t_l1}, false}
        end |> IO.inspect(label: "T_RESULT")
      end

    {{m_org_new, l1_org_new}, subtype_new?} = left_m_org |> Enum.reduce({{[], left_l1_org}, false}, fn lmo, {{acc_m_org, acc_l1_org}, acc_subtype?} ->
        acc_l1_org |> Enum.reduce({{acc_m_org, []}, acc_subtype?}, fn ll1o, {{acc_m_org_new, acc_l1_org_new}, acc_subtype_new?} ->
          case {lmo, ll1o} do
            {:empty_list, :empty_list} -> {{[], [nil]}, true}
            {:empty_list, {:non_empty_list, _}} -> {{[:empty_list], [ll1o]}, acc_subtype_new? or false}
            {{:non_empty_list, _}, :empty_list} -> {{[lmo], [:empty_list]}, acc_subtype_new? or false}
            {{:non_empty_list, {t1_m, t2_m}}, {:non_empty_list, {t1_l1, t2_l1}}} ->

              {t1_unified, t1_subtype?} = {t1_m, t1_l1} |> comparing_non_empty_lists.(comparing_non_empty_lists)
              {t2_unified, t2_subtype?} = {t2_m, t2_l1} |> comparing_non_empty_lists.(comparing_non_empty_lists)

              if t1_subtype? and t2_subtype? do
                {{acc_m_org_new, acc_l1_org_new ++ [ll1o]}, acc_subtype_new? or true}
              else
                {{acc_m_org_new ++ [{:non_empty_list, {t1_unified, t2_unified}}], acc_l1_org_new ++ [ll1o]}, acc_subtype_new? or false}
              end
          end
        end)
      end)
    org_type_new = m_org_new ++ l1_org_new
    {org_type_new, subtype_new?}
  end
  defp unify_subtypes({:fun_top, {left_m_org, left_l1_org}}) do
    # {:gradual, :fun} -> {:fun, [left_org]}
    # {:fun, _} -> {:fun_top, [left_org]}
  end
  defp unify_subtypes({_, {left_m_org, left_l1_org}}), do: (if left_m_org == left_l1_org, do: {left_l1_org, true}, else: {left_m_org ++ left_l1_org, false})

  # return (true or false) and (intersection)
  defp is_subtype?(type1, type2) do
    flatten = fn type, flatten_fun ->
        flatten_fun = &flatten_fun.(&1, flatten_fun)
        case type do
          {:union, {left_u, right_u}} -> ([left_u |> flatten_fun.()] ++ [right_u |> flatten_fun.()]) |> Enum.flat_map(fn x -> x end)
          _ -> [type]
        end
      end
    [type1, type2] = [type1, type2] |> Enum.map(fn t -> (if is_list(t), do: t, else: t |> flatten.()) |> Enum.uniq() end)




    # {{m_org_new, l1_org_new}, subtype?} = left_m_org |> Enum.reduce({{[], left_l1_org}, true}, fn lmo, {{acc_m_org, acc_l1_org}, acc_subtype?} ->
    #     acc_l1_org |> Enum.reduce({{acc_m_org, []}, acc_subtype?}, fn ll1o, {{acc_m_org_new, acc_l1_org_new}, acc_subtype_new?} ->
    #       case {lmo, ll1o} do
    #         {:empty_list, :empty_list} -> {{[], [nil]}, true}
    #         {:empty_list, {:non_empty_list, _}} -> {{[:empty_list], [ll1o]}, false}
    #         {{:non_empty_list, _}, :empty_list} -> {{[lmo], [:empty_list]}, false}
    #         {{:non_empty_list, {t1_m, t2_m}}, {:non_empty_list, {t1_l1, t2_l1}}} ->
    #           {org_type, subtype?} = {{n1_m, n2_m}, {n1_l1, n2_l1}} |> comparing_intervals.()
    #           case org_type do
    #             [org_type_m, org_type_l1] -> {{acc_m_org_new ++ [org_type_m], acc_l1_org_new ++ [org_type_l1]}, acc_subtype_new? and subtype?}
    #             [org_type_union] -> {{acc_m_org_new, acc_l1_org_new ++ [org_type_union]}, acc_subtype_new? and subtype?}
    #           end
    #       end
    #     end)
    #   end)
    # org_type_new = m_org_new ++ l1_org_new
    # {org_type_new, subtype?}
  end

  defp merge_types({:interval, {n1_f, n1_l}}, {:interval, {n2_f, n2_l}}) do
    cond do
      {n1_f, n1_l} == {n2_f, n2_l} ->
        {[{:interval, {n2_f, n2_l}}], true}
      [n1_f, n1_l, n2_f, n2_l] |> Enum.find_value(false, fn n -> n == :infty end) ->
        case {n1_f, n1_l, n2_f, n2_l} do
          {_, _, :infty, -1} -> if n1_f < 0 and n1_l < 0, do: {[{:interval, {n2_f, n2_l}}]}, else: {[{:interval, {n1_f, n1_l}}, {:interval, {n2_f, n2_l}}], false}
          {1, :infty, 0, :infty} -> {[{:interval, {n2_f, n2_l}}], true}
          {0, :infty, 1, :infty} -> {[{:interval, {n1_f, n1_l}}], false}
          {_, _, 0, :infty} -> if n1_f > -1 and n1_l > -1, do: {[{:interval, {n2_f, n2_l}}], true}, else: {[{:interval, {n1_f, n1_l}}, {:interval, {n2_f, n2_l}}], false}
          {_, _, 1, :infty} -> if n1_f > 0 and n1_l > 0, do: {[{:interval, {n2_f, n2_l}}], true}, else: {[{:interval, {n1_f, n1_l}}, {:interval, {n2_f, n2_l}}], false}
          {:infty, -1, _, _} -> if n2_f < 0 and n2_l < 0, do: {[{:interval, {n1_f, n1_l}}], false}, else: {[{:interval, {n1_f, n1_l}}, {:interval, {n2_f, n2_l}}], false}
          {1, :infty, _, _} -> if n2_f > 0 and n2_l > 0, do: {[{:interval, {n1_f, n1_l}}], false}, else: {[{:interval, {n1_f, n1_l}}, {:interval, {n2_f, n2_l}}], false}
          {0, :infty, _, _} -> if n2_f > -1 and n2_l > -1, do: {[{:interval, {n1_f, n1_l}}], false}, else: {[{:interval, {n1_f, n1_l}}, {:interval, {n2_f, n2_l}}], false}
        end
      Range.disjoint?(n1_f..n1_l, n2_f..n2_l) ->
        cond do
          n1_l + 1 == n2_f -> {[{:interval, {n1_f, n2_l}}], false}
          n2_l + 1 == n1_f -> {[{:interval, {n2_f, n1_l}}], false}
          true -> {[{:interval, {n1_f, n1_l}}, {:interval, {n2_f, n2_l}}], false}
        end
      n1_f..n1_l |> Enum.to_list() |> Enum.reduce(true, fn n, acc -> acc and Enum.member?(n2_f..n2_l, n) end) ->
        {[{:interval, {n2_f, n2_l}}], true}
      true ->
        cond do
          n1_f <= n2_f and n1_l <= n2_l -> {[{:interval, {n1_f, n2_l}}], false}
          n1_f <= n2_f and n1_l >= n2_l -> {[{:interval, {n1_f, n1_l}}], false}
          n1_f >= n2_f and n1_l <= n2_l -> {[{:interval, {n2_f, n2_l}}], false}
          n1_f >= n2_f and n1_l >= n2_l -> {[{:interval, {n2_f, n1_l}}], false}
        end
    end
  end
  defp intersection(:atom, left_m_org, left_l1_org) do
    if left_m_org == left_l1_org do
      {left_l1_org, true}
    else
      {{m_org_new, l1_org_new}, subtype_new?} = left_m_org |> Enum.reduce({{[], left_l1_org}, true}, fn lmo, {{acc_m_org, acc_l1_org}, acc_subtype?} ->
        acc_l1_org |> Enum.reduce({{acc_m_org, []}, acc_subtype?}, fn ll1o, {{acc_m_org_new, acc_l1_org_new}, acc_subtype_new?} ->
          case {lmo, ll1o} do
            {_, :atom} -> {{[], [nil]}, true}
            {:atom, _} -> {{[:atom], []}, false}
            {{:atom_req, sgt1}, {:atom_req, sgt2}} ->
              if sgt1 == sgt2 do
                {{[], acc_l1_org_new ++ [ll1o]}, acc_subtype_new? and true}
              else
                {{[lmo], []}, acc_subtype_new? and false}
              end
            _ ->
              if lmo == ll1o do
                {{acc_m_org_new, acc_l1_org_new ++ [ll1o]}, acc_subtype_new? and true}
              else
                {{acc_m_org_new ++ [lmo], acc_l1_org_new ++ [ll1o]}, acc_subtype_new? and false}
              end
          end
        end)
      end)
      org_type_new = m_org_new ++ l1_org_new
      {org_type_new, subtype_new?}
    end
  end
end
